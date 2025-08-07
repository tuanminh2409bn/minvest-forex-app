import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { Response } from "express";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import {onCall} from "firebase-functions/v2/https";
import * as crypto from "crypto";
import * as querystring from "qs";
import axios from "axios";
import {GoogleAuth} from "google-auth-library";
import { onSchedule } from "firebase-functions/v2/scheduler";

// =================================================================
// === KHỞI TẠO CÁC DỊCH VỤ CƠ BẢN ===
// =================================================================
admin.initializeApp();
const firestore = admin.firestore();

// =================================================================
// === HÀM HELPER GỬI THÔNG BÁO  ===
// =================================================================
const sendSignalDataNotification = async (
  tokens: string[],
  data: {[key: string]: string},
) => {
  if (tokens.length === 0) {
    functions.logger.warn("Không có token nào hợp lệ để gửi thông báo.");
    return;
  }

  const messages = tokens.map(token => ({
    token: token,
    data: data,
    android: {
      priority: "high" as const,
    },
    apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { "content-available": 1 } },
    },
  }));

  try {
      const response = await admin.messaging().sendEach(messages);
      functions.logger.info(`Đã gửi thông báo thành công đến ${response.successCount} thiết bị.`);

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            functions.logger.error(`Không gửi được đến token: ${tokens[idx]}`, resp.error);
          }
        });
      }
  } catch (error) {
      functions.logger.error("Lỗi khi gửi hàng loạt thông báo:", error);
  }
};

// =================================================================
// === FUNCTION XỬ LÝ ẢNH XÁC THỰC EXNESS ===
// =================================================================
export const processVerificationImage = onObjectFinalized(
  { region: "asia-southeast1", cpu: 2, memory: "1GiB" },
  async (event) => {
    const visionClient = new ImageAnnotatorClient();
    const fileBucket = event.data.bucket;
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    if (!filePath || !filePath.startsWith("verification_images/")) {
      functions.logger.log(`Bỏ qua file không liên quan: ${filePath}`);
      return null;
    }
    if (!contentType || !contentType.startsWith("image/")) {
      functions.logger.log(`Bỏ qua file không phải ảnh: ${contentType}`);
      return null;
    }

    const userId = filePath.split("/")[1].split(".")[0];
    functions.logger.log(`Bắt đầu xử lý ảnh cho user: ${userId}`);

    const userRef = firestore.collection("users").doc(userId);

    try {
      await userRef.update({
        verificationStatus: admin.firestore.FieldValue.delete(),
        verificationError: admin.firestore.FieldValue.delete(),
      });

      const [result] = await visionClient.textDetection(
        `gs://${fileBucket}/${filePath}`
      );
      const fullText = result.fullTextAnnotation?.text;

      if (!fullText) {
        throw new Error("Không đọc được văn bản nào từ ảnh.");
      }
      functions.logger.log("Văn bản đọc được:", fullText);

      const balanceRegex = /(\d{1,3}(?:,\d{3})*[.,]\d{2})(?:\s*USD)?/;
      const idRegex = /#\s*(\d{7,})/;

      const balanceMatch = fullText.match(balanceRegex);
      const idMatch = fullText.match(idRegex);

      if (!balanceMatch || !idMatch) {
        throw new Error("Không tìm thấy đủ thông tin Số dư và ID trong ảnh.");
      }

      const balanceString = balanceMatch[1].replace(/,/g, "");
      const balance = parseFloat(balanceString);
      const exnessId = idMatch[1];

      functions.logger.log(`Tìm thấy - Số dư: ${balance}, ID Exness: ${exnessId}`);

      const affiliateCheckUrl = `https://chcke.minvest.vn/api/users/check-allocation?mt4Account=${exnessId}`;
      functions.logger.log("Đang gọi API kiểm tra affiliate:", affiliateCheckUrl);

      try {
        const response = await axios.get(affiliateCheckUrl);
        if (!response.data || !response.data.client_uid) {
          throw new Error("API không trả về dữ liệu hợp lệ.");
        }
        functions.logger.log("Kiểm tra affiliate thành công, kết quả:", response.data);
      } catch (apiError) {
        functions.logger.error("Lỗi khi kiểm tra affiliate:", apiError);
        throw new Error(`Account ${exnessId} is not under mInvest's affiliate link.`);
      }

      const idDoc = await firestore
        .collection("verifiedExnessIds")
        .doc(exnessId).get();

      if (idDoc.exists) {
        throw new Error(`ID Exness ${exnessId} has already been used.`);
      }

      let tier = "demo";
      if (balance >= 500) {
        tier = "elite";
      } else if (balance >= 200) {
        tier = "vip";
      }

      functions.logger.log(`Phân quyền cho user ${userId}: ${tier}`);

      const idRef = firestore.collection("verifiedExnessIds").doc(exnessId);

      await Promise.all([
        userRef.set({subscriptionTier: tier, verificationStatus: "success"}, {merge: true}),
        idRef.set({userId: userId, processedAt: admin.firestore.FieldValue.serverTimestamp()}),
      ]);

      functions.logger.log("Hoàn tất phân quyền thành công!");
      return null;
    } catch (error) {
      const errorMessage = (error as Error).message;
      functions.logger.error("Xử lý ảnh thất bại:", errorMessage);

      await userRef.set(
        {verificationStatus: "failed", verificationError: errorMessage},
        {merge: true}
      );
      return null;
    }
  });


// =================================================================
// === FUNCTION TẠO LINK THANH TOÁN VNPAY ===
// =================================================================
const TMN_CODE = "EZTRTEST";
const HASH_SECRET = "DGTXQMK0DF9NZTZBH63RV3AM3E53K8AX";
const VNP_URL = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
const RETURN_URL = "https://sandbox.vnpayment.vn/tryitnow/Home/VnPayReturn";
const USD_TO_VND_RATE = 25500;

export const createVnpayOrder = onCall({ region: "asia-southeast1" }, async (request) => {
  functions.logger.info("Đã nhận được yêu cầu thanh toán với dữ liệu:", request.data);

  const amountUSD = request.data.amount;
  const orderInfo = request.data.orderInfo;

  if (!amountUSD || !orderInfo) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Function cần được gọi với 'amount' và 'orderInfo'."
    );
  }

  const amountVND = Math.round(amountUSD * USD_TO_VND_RATE) * 100;
  const createDate = new Date().toISOString().replace(/T|Z|\..*$/g, "").replace(/[-:]/g, "");
  const orderId = createDate + Math.random().toString().slice(2, 8);
  const ipAddr = request.rawRequest.ip || "127.0.0.1";

  let vnpParams: any = {};
  vnpParams["vnp_Version"] = "2.1.0";
  vnpParams["vnp_Command"] = "pay";
  vnpParams["vnp_TmnCode"] = TMN_CODE;
  vnpParams["vnp_Locale"] = "vn";
  vnpParams["vnp_CurrCode"] = "VND";
  vnpParams["vnp_TxnRef"] = orderId;
  vnpParams["vnp_OrderInfo"] = orderInfo;
  vnpParams["vnp_OrderType"] = "other";
  vnpParams["vnp_Amount"] = amountVND;
  vnpParams["vnp_ReturnUrl"] = RETURN_URL;
  vnpParams["vnp_IpAddr"] = ipAddr;
  vnpParams["vnp_CreateDate"] = createDate;

  vnpParams = Object.keys(vnpParams)
    .sort()
    .reduce((acc, key) => {
      acc[key] = vnpParams[key];
      return acc;
    }, {} as any);

  let signData = querystring.stringify(vnpParams, { encode: true });
  signData = signData.replace(/%20/g, "+");

  const hmac = crypto.createHmac("sha521", HASH_SECRET);
  const signed = hmac.update(Buffer.from(signData, "utf-8")).digest("hex");
  vnpParams["vnp_SecureHash"] = signed;

  const paymentUrl = VNP_URL + "?" + querystring.stringify(vnpParams, {encode: true});

  functions.logger.info("URL thanh toán được tạo:", paymentUrl);

  return {paymentUrl: paymentUrl};
});


// =================================================================
// === FUNCTION WEBHOOK CHO TELEGRAM BOT ===
// =================================================================
const TELEGRAM_CHAT_ID = "-1002785712406";

export const telegramWebhook = functions.https.onRequest(
  {
    region: "asia-southeast1",
    timeoutSeconds: 30,
    memory: "512MiB",
  },
  async (req: functions.https.Request, res: Response) => {
    if (req.method !== "POST") {
      res.status(403).send("Forbidden!");
      return;
    }

    const update = req.body;
    const message = update.message || update.channel_post;

    if (!message || message.chat.id.toString() !== TELEGRAM_CHAT_ID) {
      functions.logger.log(`Bỏ qua tin nhắn từ chat ID không xác định: ${message?.chat.id}`);
      res.status(200).send("OK");
      return;
    }

    try {
      // =================================================
      // === KỊCH BẢN 1: TIN NHẮN TRẢ LỜI (CẬP NHẬT) ===
      // =================================================
      if (message.reply_to_message && message.text) {
        functions.logger.log("Phát hiện tin nhắn trả lời, bắt đầu xử lý cập nhật...");
        const originalMessageId = message.reply_to_message.message_id;
        const updateText = message.text.toLowerCase();

        const signalQuery = await firestore.collection("signals")
            .where("telegramMessageId", "==", originalMessageId).limit(1).get();

        if (signalQuery.empty) {
          functions.logger.warn(`Không tìm thấy tín hiệu gốc với ID: ${originalMessageId}`);
          res.status(200).send("OK. No original signal found.");
          return;
        }

        const signalDoc = signalQuery.docs[0];
        const signalRef = signalDoc.ref;

        // KỊCH BẢN 2: ĐÃ KHỚP LỆNH -> Cập nhật isMatched = true, vẫn LIVE
        if (updateText.includes("đã khớp entry tại giá")) {
          await signalRef.update({
            isMatched: true,
            result: "Matched", // Cập nhật result để dễ theo dõi
            matchedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          functions.logger.log(`Tín hiệu ${signalDoc.id} đã KHỚP LỆNH (MATCHED).`);

        // KỊCH BẢN 3: HIT TP1/TP2 -> Cập nhật result, vẫn LIVE
        } else if (updateText.includes("tp1 hit") || updateText.includes("tp2 hit")) {
          const resultText = updateText.includes("tp1 hit") ? "TP1 Hit" : "TP2 Hit";
          await signalRef.update({
             // status vẫn là "running"
             result: resultText,
          });
          functions.logger.log(`Tín hiệu ${signalDoc.id} đã ${resultText}, vẫn LIVE.`);

        // KỊCH BẢN 4, 6, 7: SL HIT, TP3 HIT, EXIT, BỎ LỆNH -> Chuyển sang END
        } else {
            let resultText = "Exited"; // Mặc định
            let shouldEnd = true;

            if (updateText.includes("sl hit")) resultText = "SL Hit";
            else if (updateText.includes("tp3 hit")) resultText = "TP3 Hit";
            else if (updateText.includes("exit tại giá") || updateText.includes("exit lệnh")) resultText = "Exited by Admin";
            else if (updateText.includes("bỏ tín hiệu")) resultText = "Cancelled";
            else shouldEnd = false;

            if (shouldEnd) {
              await signalRef.update({
                status: "closed",
                result: resultText,
                closedAt: admin.firestore.FieldValue.serverTimestamp()
              });
              functions.logger.log(`Tín hiệu ${signalDoc.id} đã chuyển sang END với kết quả: ${resultText}`);
            }
        }

      // =================================================
      // === KỊCH BẢN 2: TIN NHẮN MỚI (TẠO TÍN HIỆU) ===
      // =================================================
      } else if (message.text) {
        const signalData = parseSignalMessage(message.text);

        if (signalData) {
          // LOGGING NÂNG CẤP
          functions.logger.log("Phát hiện tín hiệu mới. Dữ liệu đã phân tích:", JSON.stringify(signalData));

          const batch = firestore.batch();

          // BƯỚC 1: HỦY TÍN HIỆU CŨ CHƯA KHỚP
          const unmatchedQuery = await firestore.collection("signals")
            .where("status", "==", "running")
            .where("isMatched", "==", false).get();

          if (!unmatchedQuery.empty) {
            functions.logger.log(`Tìm thấy ${unmatchedQuery.size} tín hiệu chưa khớp để hủy.`);
            unmatchedQuery.forEach(doc => {
              functions.logger.log(`--> Đang hủy tín hiệu: ${doc.id}`);
              batch.update(doc.ref, { status: "closed", result: "Cancelled (new signal)" });
            });
          }

          // BƯỚC 2: ĐÓNG TÍN HIỆU NGƯỢC CHIỀU ĐÃ TP1/2
          const oppositeType = signalData.type === 'buy' ? 'sell' : 'buy';
          const runningTpQuery = await firestore.collection("signals")
              .where("status", "==", "running")
              .where("type", "==", oppositeType)
              .where("result", "in", ["TP1 Hit", "TP2 Hit"]).get();

          if (!runningTpQuery.empty) {
            functions.logger.log(`Tìm thấy ${runningTpQuery.size} tín hiệu ngược chiều đã TP1/2 để đóng.`);
            runningTpQuery.forEach(doc => {
              functions.logger.log(`--> Đang đóng tín hiệu: ${doc.id}`);
              batch.update(doc.ref, { status: "closed" });
            });
          }

          // BƯỚC 3: TẠO TÍN HIỆU MỚI
          const newSignalRef = firestore.collection("signals").doc();
          batch.set(newSignalRef, {
            ...signalData,
            telegramMessageId: message.message_id,
            createdAt: admin.firestore.Timestamp.fromMillis(message.date * 1000),
            status: "running",
            isMatched: false,
            result: "Not Matched",
          });

          await batch.commit();

          // LOGGING NÂNG CẤP
          functions.logger.log(`Hoàn tất! Đã tạo tín hiệu mới với ID: ${newSignalRef.id}`);

        } else {
          functions.logger.log("Tin nhắn không phải là tín hiệu hợp lệ, bỏ qua.");
        }
      }

      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("Lỗi nghiêm trọng khi xử lý tin nhắn Telegram:", error);
      res.status(500).send("Internal Server Error");
    }
  }
);

// Hàm phân tích tin nhắn (đã tinh chỉnh)
function parseSignalMessage(text: string): any | null {
    const signal: any = { takeProfits: [] };

    const signalPart = text.split("=== GIẢI THÍCH ===")[0];
    if (!signalPart) return null;

    const lines = signalPart.split("\n");
    const titleLine = lines.find((line) => line.includes("Tín hiệu:"));
    if (!titleLine) return null;

    if (titleLine.includes("BUY")) signal.type = "buy";
    else if (titleLine.includes("SELL")) signal.type = "sell";
    else return null;

    const symbolRegex = /\b([A-Z]{3}\/[A-Z]{3}|XAU\/USD)\b/i;
    const symbolMatch = titleLine.match(symbolRegex);
    if (symbolMatch) {
        signal.symbol = symbolMatch[0].toUpperCase();
    } else {
        signal.symbol = "XAU/USD";
    }

    for (const line of lines) {
        const entryRegex = /Entry:\s*([\d.]+)/;
        const entryMatch = line.match(entryRegex);
        if (entryMatch) signal.entryPrice = parseFloat(entryMatch[1]);

        const slRegex = /SL:\s*([\d.]+)/;
        const slMatch = line.match(slRegex);
        if (slMatch) signal.stopLoss = parseFloat(slMatch[1]);

        const tpRegex = /TP\d*:\s*([\d.]+)/g;
        let tpMatch;
        while ((tpMatch = tpRegex.exec(line)) !== null) {
            signal.takeProfits.push(parseFloat(tpMatch[1]));
        }
    }

    const reasonIndex = text.indexOf("=== GIẢI THÍCH ===");
    if (reasonIndex !== -1) {
        signal.reason = text.substring(reasonIndex).replace(/=== GIẢI THÍCH ===/i, "").trim();
    }

    if (signal.type && signal.symbol && signal.entryPrice && signal.stopLoss && signal.takeProfits.length > 0) {
        return signal;
    }

    return null;
}

// =================================================================
// === FUNCTION XÁC THỰC GIAO DỊCH IN-APP PURCHASE ===
// =================================================================
export const verifyPurchase = onCall({ region: "asia-southeast1" }, async (request) => {
    const productId = request.data.productId;
    const purchaseToken = request.data.purchaseToken;
    const packageName = "com.minvest.aisignals"; // Thay thế nếu package name của bạn khác
    const userId = request.auth?.uid;

    if (!userId) {
        throw new functions.https.HttpsError("unauthenticated", "Người dùng chưa đăng nhập.");
    }
    if (!productId || !purchaseToken) {
        throw new functions.https.HttpsError("invalid-argument", "Thiếu productId hoặc purchaseToken.");
    }

    try {
        functions.logger.log(`Bắt đầu xác thực cho user: ${userId}, sản phẩm: ${productId}`);

        // 1. Xác thực với Google Play Developer API
        const auth = new GoogleAuth({
            scopes: "https://www.googleapis.com/auth/androidpublisher",
        });
        const authClient = await auth.getClient();

        const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;

        const res = await authClient.request({ url });
        functions.logger.log("Phản hồi từ Google Play API:", res.data);

        // 2. Kiểm tra kết quả xác thực
        if (res.data && (res.data as any).purchaseState === 0) {
            // purchaseState === 0 nghĩa là giao dịch đã hoàn tất
            functions.logger.log("Xác thực thành công!");

            // 3. Nâng cấp tài khoản người dùng trên Firestore
            const userRef = firestore.collection("users").doc(userId);
            const now = new Date();
            let expiryDate = new Date();

            if (productId === "elite_1_month") {
                expiryDate = new Date(now.setMonth(now.getMonth() + 1));
            } else if (productId === "elite_12_months") {
                expiryDate = new Date(now.setFullYear(now.getFullYear() + 1));
            } else {
                 throw new functions.https.HttpsError("invalid-argument", "Sản phẩm không hợp lệ.");
            }

            await userRef.update({
                subscriptionTier: "elite",
                subscriptionExpiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
            });

            functions.logger.log(`Đã nâng cấp tài khoản ${userId} lên Elite. Hết hạn vào: ${expiryDate.toISOString()}`);
            return { success: true, message: "Tài khoản đã được nâng cấp." };
        } else {
            // Giao dịch chưa hoàn tất hoặc đã bị hủy
            throw new functions.https.HttpsError("aborted", "Giao dịch không hợp lệ hoặc đã bị hủy.");
        }
    } catch (error) {
        functions.logger.error("Lỗi nghiêm trọng khi xác thực giao dịch:", error);
        throw new functions.https.HttpsError("internal", "Đã xảy ra lỗi trong quá trình xác thực.");
    }
});

// =================================================================
// === FUNCTION GỬI THÔNG BÁO ĐẨY KHI CÓ TÍN HIỆU MỚI ===
// =================================================================
export const sendSignalNotification = onDocumentCreated(
  {
    document: "signals/{signalId}",
    region: "asia-southeast1",
    memory: "256MiB",
  },
  async (event) => {
    const signalData = event.data?.data();
    const signalId = event.params.signalId;

    if (!signalData) {
      functions.logger.log("Không có dữ liệu tín hiệu mới, bỏ qua.");
      return;
    }

    const symbol = signalData.symbol;
    const type = signalData.type.toUpperCase();
    functions.logger.log(`Tín hiệu mới: ${type} ${symbol}. Bắt đầu gửi thông báo.`);

    const usersSnapshot = await firestore.collection("users").get();
    if (usersSnapshot.empty) {
        functions.logger.log("Không tìm thấy người dùng nào.");
        return;
    }

    const tokens = usersSnapshot.docs
        .map(doc => doc.data().activeSession?.fcmToken)
        .filter(token => token);

    if (tokens.length === 0) {
        functions.logger.log("Không có user nào có fcmToken hợp lệ.");
        return;
    }

    functions.logger.log(`Chuẩn bị gửi thông báo TẠO MỚI đến ${tokens.length} thiết bị.`);

    const dataPayload = {
      type: "new_signal", // Loại thông báo
      signalId: signalId,   // ID để điều hướng
      title: `⚡️ Tín hiệu mới: ${type} ${symbol}`,
      body: `Entry: ${signalData.entryPrice} | SL: ${signalData.stopLoss}`,
    };

    await sendSignalDataNotification(tokens, dataPayload);
  }
);


// =================================================================
// === GỬI THÔNG BÁO KHI TÍN HIỆU ĐƯỢC CẬP NHẬT ===
// =================================================================
export const sendSignalUpdateNotification = onDocumentUpdated(
  {
    document: "signals/{signalId}",
    region: "asia-southeast1",
    memory: "256MiB",
  },

  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const signalId = event.params.signalId;

    if (!beforeData || !afterData) {
      functions.logger.log("Thiếu dữ liệu trước/sau, bỏ qua.");
      return;
    }

    let title = "";
    let body = "";
    let type = "";

    const symbol = afterData.symbol;
    const signalType = afterData.type.toUpperCase();

    // 1. KIỂM TRA THAY ĐỔI TRẠNG THÁI KHỚP LỆNH
    if (beforeData.isMatched === false && afterData.isMatched === true) {
        type = "signal_matched";
        title = `✅ ${signalType} ${symbol} Đã khớp lệnh!`;
        body = `Tín hiệu đã khớp entry tại giá ${afterData.entryPrice}.`;
    }
    // 2. KIỂM TRA THAY ĐỔI KẾT QUẢ (TP/SL)
    else if (beforeData.result !== afterData.result) {
        switch(afterData.result) {
            case "TP1 Hit":
                type = "tp1_hit";
                title = `🎯 ${signalType} ${symbol} đã đạt TP1!`;
                body = `Chúc mừng! Tín hiệu đã chốt lời ở mức TP1.`;
                break;
            case "TP2 Hit":
                type = "tp2_hit";
                title = `🎯🎯 ${signalType} ${symbol} đã đạt TP2!`;
                body = `Xuất sắc! Tín hiệu tiếp tục chốt lời ở mức TP2.`;
                break;
            case "TP3 Hit":
                type = "tp3_hit";
                title = `🏆 ${signalType} ${symbol} đã đạt TP3!`;
                body = `Mục tiêu cuối cùng đã hoàn thành!`;
                break;
            case "SL Hit":
                type = "sl_hit";
                title = `❌ ${signalType} ${symbol} đã chạm Stop Loss.`;
                body = `Rất tiếc, tín hiệu đã chạm điểm dừng lỗ.`;
                break;
        }
    }

    if (!title) {
      return;
    }

    functions.logger.log(`Tín hiệu ${signalId} có cập nhật: ${type}. Bắt đầu gửi thông báo.`);

    const usersSnapshot = await firestore.collection("users").get();
    if (usersSnapshot.empty) return;

    const tokens = usersSnapshot.docs
        .map(doc => doc.data().activeSession?.fcmToken)
        .filter(token => token);

    if (tokens.length === 0) return;

    functions.logger.log(`Chuẩn bị gửi thông báo CẬP NHẬT đến ${tokens.length} thiết bị.`);

    const dataPayload = { type, signalId, title, body };
    await sendSignalDataNotification(tokens, dataPayload);
  }
);

// =================================================================
// === FUNCTION QUẢN LÝ PHIÊN ĐĂNG NHẬP (ĐĂNG NHẬP 1 THIẾT BỊ) ===
// =================================================================
export const manageUserSession = onCall({ region: "asia-southeast1" }, async (request) => {
  // 1. Kiểm tra xem người dùng đã xác thực chưa
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  // 2. Lấy thông tin cần thiết từ client và context
  const uid = request.auth.uid;
  const newDeviceId = request.data.deviceId;
  const newFcmToken = request.data.fcmToken;

  if (!newDeviceId || !newFcmToken) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'deviceId' and 'fcmToken' arguments."
    );
  }

  const userDocRef = firestore.collection("users").doc(uid);

  try {
    // Bắt đầu một transaction để đảm bảo an toàn dữ liệu
    await firestore.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userDocRef);

      // Nếu không có document, có thể tạo mới (tùy vào luồng đăng ký của bạn)
      if (!userDoc.exists) {
        functions.logger.log(`User document for UID ${uid} does not exist. Creating one.`);
        // Trong trường hợp này, chúng ta chỉ cần set dữ liệu session mới
        // vì không có session cũ nào để xử lý.
      }

      const userData = userDoc.data();
      const currentSession = userData?.activeSession;

      // 3. Kiểm tra và xử lý phiên đăng nhập cũ
      if (
        currentSession &&
        currentSession.deviceId &&
        currentSession.deviceId !== newDeviceId &&
        currentSession.fcmToken
      ) {
        functions.logger.log(
          `User ${uid} logging in with new device ${newDeviceId}. Logging out old device ${currentSession.deviceId}.`
        );

        // Chuẩn bị thông báo để gửi đến thiết bị cũ
        const message = {
          token: currentSession.fcmToken,
          data: {
            action: "FORCE_LOGOUT", // "Lệnh" yêu cầu đăng xuất
          },
          // Cấu hình để đảm bảo thông báo được xử lý ở chế độ nền
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { "content-available": 1 } },
          },
          android: {
            priority: "high" as const,
          },
        };

        // Gửi lệnh đăng xuất và bắt lỗi (nhưng không dừng luồng chính)
        try {
          await admin.messaging().send(message);
          functions.logger.log(`Successfully sent FORCE_LOGOUT to ${currentSession.fcmToken}`);
        } catch (error) {
          functions.logger.error(`Error sending FORCE_LOGOUT to ${currentSession.fcmToken}:`, error);
          // Ghi nhận lỗi nhưng không dừng lại, vì token cũ có thể đã hết hạn.
        }
      }

      // 4. Cập nhật phiên đăng nhập mới nhất
      const newSessionData = {
        deviceId: newDeviceId,
        fcmToken: newFcmToken,
        loginAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Dùng 'set' với 'merge: true' sẽ tạo mới document nếu chưa có,
      // hoặc chỉ cập nhật trường activeSession nếu đã có.
      transaction.set(userDocRef, { activeSession: newSessionData }, { merge: true });
    });

    functions.logger.log(`Successfully managed session for user ${uid}. Device ${newDeviceId} is now active.`);
    return { status: "success", message: "Session managed successfully." };

  } catch (error) {
    functions.logger.error("Error in manageUserSession transaction:", error);
    throw new functions.https.HttpsError(
      "internal",
      "An error occurred while managing the user session."
    );
  }
});

// =================================================================
// === FUNCTION DÀNH CHO ADMIN QUẢN LÝ TÀI KHOẢN NGƯỜI DÙNG ===
// =================================================================
export const manageUserStatus = onCall({ region: "asia-southeast1" }, async (request) => {
    // 1. KIỂM TRA QUYỀN ADMIN - BƯỚC BẢO MẬT QUAN TRỌNG NHẤT
    const adminUid = request.auth?.uid;
    if (!adminUid) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Bạn phải đăng nhập để thực hiện hành động này."
        );
    }

    const adminUserDoc = await firestore.collection("users").doc(adminUid).get();
    if (adminUserDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Bạn không có quyền thực hiện hành động này."
        );
    }

    // 2. Lấy dữ liệu từ client gửi lên
    const { userIds, newStatus, reason } = request.data;
    if (!userIds || !Array.isArray(userIds) || !newStatus) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Dữ liệu gửi lên không hợp lệ."
        );
    }

    functions.logger.log(`Admin ${adminUid} is updating ${userIds.length} users to status: ${newStatus}`);

    // 3. Xử lý logic khóa/mở khóa cho từng user
    const batch = firestore.batch();
    const fcmTokensToNotify: string[] = [];

    for (const userId of userIds) {
        if (userId === adminUid) {
            functions.logger.warn(`Admin ${adminUid} attempted to lock their own account. Skipping.`);
            continue; // Admin không thể tự khóa tài khoản của mình
        }

        const userRef = firestore.collection("users").doc(userId);

        if (newStatus === "suspended") {
            // Logic khi KHÓA tài khoản
            batch.update(userRef, {
                isSuspended: true,
                suspensionReason: reason || "Tài khoản của bạn đã bị tạm ngưng. Vui lòng liên hệ quản trị viên.",
            });

            // Lấy FCM token để gửi thông báo logout
            const userDoc = await userRef.get();
            const fcmToken = userDoc.data()?.activeSession?.fcmToken;
            if (fcmToken) {
                fcmTokensToNotify.push(fcmToken);
            }

        } else if (newStatus === "active") {
            // Logic khi MỞ KHÓA tài khoản
            batch.update(userRef, {
                isSuspended: false,
                suspensionReason: admin.firestore.FieldValue.delete(), // Xóa lý do khóa
            });
        }
    }

    // 4. Gửi các lệnh cập nhật lên Firestore cùng lúc
    await batch.commit();

    // 5. Nếu là lệnh khóa, gửi thông báo đăng xuất đến các thiết bị
    if (newStatus === "suspended" && fcmTokensToNotify.length > 0) {
        const message = {
            data: {
                action: "FORCE_LOGOUT",
                reason: reason || "Tài khoản của bạn đã bị tạm ngưng bởi quản trị viên.",
            },
            apns: {
                headers: { "apns-priority": "10" },
                payload: { aps: { "content-available": 1 } },
            },
            android: {
                priority: "high" as const,
            },
        };

        // Gửi thông báo đến từng token
        for (const token of fcmTokensToNotify) {
            try {
                await admin.messaging().send({ ...message, token });
                functions.logger.log(`Sent suspension notification to token: ${token}`);
            } catch (error) {
                functions.logger.error(`Error sending notification to ${token}`, error);
            }
        }
    }

    return { status: "success", message: `Đã cập nhật thành công ${userIds.length} tài khoản.` };
});

// =================================================================
// === FUNCTION MỚI: TỰ ĐỘNG KIỂM TRA TÍN HIỆU QUÁ HẠN (TIMEOUT) ===
// =================================================================
export const checkSignalTimeouts = onSchedule(
    {
        schedule: "every 10 minutes", // Lịch trình chạy
        region: "asia-southeast1",    // Chỉ định region
        timeZone: "Asia/Ho_Chi_Minh", // Thêm múi giờ để đảm bảo chạy đúng giờ Việt Nam
    },
    async (event) => {
        functions.logger.log("Bắt đầu chạy trình kiểm tra tín hiệu quá hạn...");

        const now = admin.firestore.Timestamp.now();
        const timeoutThreshold = admin.firestore.Timestamp.fromMillis(
            now.toMillis() - 20 * 60 * 1000
        );

        try {
            const overdueSignalsQuery = firestore.collection("signals")
                .where("status", "==", "running")
                .where("isMatched", "==", true)
                .where("matchedAt", "<=", timeoutThreshold);

            const overdueSignals = await overdueSignalsQuery.get();

            if (overdueSignals.empty) {
                functions.logger.log("Không tìm thấy tín hiệu nào quá hạn. Kết thúc.");
                return;
            }

            functions.logger.log(`Phát hiện ${overdueSignals.size} tín hiệu quá hạn. Bắt đầu xử lý...`);

            const batch = firestore.batch();
            overdueSignals.forEach(doc => {
                functions.logger.log(`--> Đang đóng tín hiệu ${doc.id} do timeout.`);
                batch.update(doc.ref, {
                    status: "closed",
                    result: "Exited (Timeout)",
                    closedAt: now
                });
            });

            await batch.commit();
            functions.logger.log("Đã đóng thành công tất cả các tín hiệu quá hạn.");
            return;

        } catch (error) {
            functions.logger.error("Lỗi nghiêm trọng khi kiểm tra tín hiệu quá hạn:", error);
            return;
        }
    }
);
