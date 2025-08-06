import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { Response } from "express";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import {onCall} from "firebase-functions/v2/https";
import * as crypto from "crypto";
import * as querystring from "qs";
import axios from "axios";
import {GoogleAuth} from "google-auth-library";

// =================================================================
// === KHỞI TẠO CÁC DỊCH VỤ CƠ BẢN ===
// =================================================================
admin.initializeApp();
const firestore = admin.firestore();

// =================================================================
// === HÀM HELPER GỬI THÔNG BÁO (THEO PHONG CÁCH CỦA BẠN) ===
// =================================================================
const sendSignalDataNotification = async (
  tokens: string[],
  data: {[key: string]: string},
) => {
  if (tokens.length === 0) {
    functions.logger.warn("Không có token nào hợp lệ để gửi thông báo.");
    return;
  }

  // Cấu hình riêng cho Android để ưu tiên hiển thị thông báo
  const message = {
    data: data,
    android: {
      priority: "high" as const,
    },
  };

  try {
      const response = await admin.messaging().sendToDevice(tokens, message);
      functions.logger.info(`Đã gửi thông báo thành công đến ${response.successCount} thiết bị.`);
      // Có thể thêm logic xử lý token lỗi ở đây nếu cần
  } catch (error) {
      functions.logger.error("Lỗi khi gửi thông báo:", error);
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
const TELEGRAM_CHAT_ID = "-1002866162244";

export const telegramWebhook = functions.https.onRequest(
  {
    region: "asia-southeast1",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req: functions.https.Request, res: Response) => {
    if (req.method !== "POST") {
      res.status(403).send("Forbidden!");
      return;
    }

    const update = req.body;
    const message = update.message || update.channel_post;

    if (!message || message.chat.id.toString() !== TELEGRAM_CHAT_ID) {
      functions.logger.info(`Bỏ qua tin nhắn từ chat ID không xác định: ${message?.chat.id}`);
      res.status(200).send("OK");
      return;
    }

    try {
      // Trường hợp 1: Tin nhắn trả lời (cập nhật trạng thái END)
      if (message.reply_to_message && message.text) {
        functions.logger.log("Phát hiện tin nhắn trả lời, bắt đầu xử lý cập nhật trạng thái...");

        const originalMessageId = message.reply_to_message.message_id;
        const updateText = message.text.toLowerCase();

        const signalQuery = await firestore.collection("signals")
            .where("telegramMessageId", "==", originalMessageId).limit(1).get();

        if (signalQuery.empty) {
          functions.logger.warn(`Không tìm thấy tín hiệu gốc với ID tin nhắn: ${originalMessageId}`);
          res.status(200).send("OK. No original signal found.");
          return;
        }

        const signalDoc = signalQuery.docs[0];
        let resultText = "Exited";

        if (updateText.includes("sl hit")) resultText = "SL Hit";
        else if (updateText.includes("tp1 hit")) resultText = "TP1 Hit";
        else if (updateText.includes("tp2 hit")) resultText = "TP2 Hit";
        else if (updateText.includes("tp3 hit")) resultText = "TP3 Hit";
        else if (updateText.includes("exit tại giá") || updateText.includes("exit lệnh")) resultText = "Exited by Admin";
        else if (updateText.includes("bỏ tín hiệu")) resultText = "Cancelled";

        await signalDoc.ref.update({
          status: "closed",
          result: resultText,
          closedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        functions.logger.log(`Thành công! Đã cập nhật tín hiệu ${signalDoc.id} sang trạng thái END với kết quả: ${resultText}`);

      // Trường hợp 2: Tin nhắn mới (tạo tín hiệu)
      } else if (message.text) {
        functions.logger.log("Phát hiện tin nhắn mới, bắt đầu xử lý tạo tín hiệu...");
        const signalData = parseSignalMessage(message.text);

        if (signalData) {
          await firestore.collection("signals").add({
            ...signalData,
            telegramMessageId: message.message_id,
            createdAt: admin.firestore.Timestamp.fromMillis(message.date * 1000),
            status: "running",
            isMatched: false,
            sourceTier: "elite",
          });
          functions.logger.log("Thành công! Đã tạo tín hiệu mới.", signalData);
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
    else return null; // Bắt buộc phải có BUY hoặc SELL

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
// === GIAI ĐOẠN 3: FUNCTION GỬI THÔNG BÁO ĐẨY KHI CÓ TÍN HIỆU MỚI ===
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
      functions.logger.log("Không có dữ liệu tín hiệu, bỏ qua.");
      return;
    }

    const symbol = signalData.symbol;
    const type = signalData.type.toUpperCase();

    functions.logger.log(`Tín hiệu mới: ${type} ${symbol}. Bắt đầu gửi thông báo.`);

    // 1. Lấy FCM token của TẤT CẢ người dùng (không phân biệt hạng)
    const usersSnapshot = await firestore.collection("users")
        .where("fcmToken", "!=", null)
        .get();

    if (usersSnapshot.empty) {
        functions.logger.log("Không tìm thấy người dùng nào có fcmToken.");
        return;
    }

    const tokens = usersSnapshot.docs.map(doc => doc.data().fcmToken).filter(token => token);
    functions.logger.log(`Chuẩn bị gửi thông báo đến ${tokens.length} thiết bị.`);

    // 2. Tạo nội dung DATA cho thông báo
    // App sẽ dựa vào đây để tự xây dựng và hiển thị thông báo
    const dataPayload = {
      // Các key này cần khớp với logic xử lý ở phía app Flutter
      type: "new_signal",
      signalId: signalId,
      title: `⚡️ Tín hiệu mới: ${type} ${symbol}`,
      body: `Entry: ${signalData.entryPrice} | SL: ${signalData.stopLoss} | TP1: ${signalData.takeProfits[0]}`,
    };

    // 3. Gọi hàm helper để gửi thông báo
    await sendSignalDataNotification(tokens, dataPayload);
  }
);

