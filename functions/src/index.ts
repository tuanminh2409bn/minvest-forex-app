import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
// ▼▼▼ THÊM DÒNG NÀY ĐỂ SỬA LỖI ▼▼▼
import { Response } from "express";
// ▲▲▲ KẾT THÚC PHẦN THÊM MỚI ▲▲▲
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import {onCall} from "firebase-functions/v2/https";
import * as crypto from "crypto";
import * as querystring from "qs";
import axios from "axios";

// =================================================================
// === KHỞI TẠO CÁC DỊCH VỤ CƠ BẢN ===
// =================================================================
admin.initializeApp();
const firestore = admin.firestore();

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

  const hmac = crypto.createHmac("sha512", HASH_SECRET);
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
    memory: "128MiB",
  },
  // ▼▼▼ PHẦN ĐÃ SỬA LỖI CUỐI CÙNG ▼▼▼
  async (req: functions.https.Request, res: Response) => {
  // ▲▲▲ KẾT THÚC PHẦN SỬA LỖI ▲▲▲
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

    const messageText = message.text;
    if (!messageText) {
      res.status(200).send("OK");
      return;
    }

    functions.logger.log("Đã nhận được tin nhắn từ nhóm:", messageText);

    try {
      const signalData = parseSignalMessage(messageText);

      if (signalData) {
        await firestore.collection("signals").add({
          ...signalData,
          telegramMessageId: message.message_id,
          createdAt: admin.firestore.Timestamp.fromMillis(message.date * 1000),
          status: "pending",
          isMatched: false,
          sourceTier: "elite",
        });
        functions.logger.log("Đã tạo tín hiệu mới thành công!", signalData);
      } else {
        functions.logger.log("Tin nhắn không phải là tín hiệu mới, bỏ qua.");
      }

      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("Lỗi khi xử lý tin nhắn Telegram:", error);
      res.status(500).send("Internal Server Error");
    }
  }
);

function parseSignalMessage(text: string): any | null {
  if (!text.includes("Tín hiệu:") || !text.includes("GIẢI THÍCH")) {
    return null;
  }

  const lines = text.split("\n");
  const signal: any = {
    takeProfits: [],
  };

  const symbolRegex = /([A-Z]{3}\/[A-Z]{3}|XAU\/USD)/i;
  const entryRegex = /Entry:\s*([\d.]+)/;
  const slRegex = /SL:\s*([\d.]+)/;
  const tpRegex = /TP(\d*):\s*([\d.]+)/g;

  const symbolMatch = text.match(symbolRegex);
  if (symbolMatch) {
    signal.symbol = symbolMatch[0].toUpperCase();
  } else {
    signal.symbol = "XAU/USD";
  }

  for (const line of lines) {
    if (line.includes("Tín hiệu: BUY")) signal.type = "buy";
    if (line.includes("Tín hiệu: SELL")) signal.type = "sell";

    const entryMatch = line.match(entryRegex);
    if (entryMatch) signal.entryPrice = parseFloat(entryMatch[1]);

    const slMatch = line.match(slRegex);
    if (slMatch) signal.stopLoss = parseFloat(slMatch[1]);

    let tpMatch;
    while ((tpMatch = tpRegex.exec(line)) !== null) {
      signal.takeProfits.push(parseFloat(tpMatch[2]));
    }
  }

  const reasonIndex = text.indexOf("=== GIẢI THÍCH ===");
  if (reasonIndex !== -1) {
    signal.reason = text.substring(reasonIndex).replace(/=== GIẢI THÍCH ===/i, "").trim();
  }

  if (signal.type && signal.symbol && signal.entryPrice && signal.stopLoss) {
    return signal;
  }

  return null;
}