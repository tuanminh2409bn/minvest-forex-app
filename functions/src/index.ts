import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { v2 as translate } from '@google-cloud/translate';
import axios from "axios";
import { GoogleAuth } from "google-auth-library";
import { Response } from "express";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getLocalizedPayload } from "./localization";

// =================================================================
// === KHỞI TẠO CÁC DỊCH VỤ CƠ BẢN ===
// =================================================================
admin.initializeApp();
const firestore = admin.firestore();
const translateClient = new translate.Translate();

const PRODUCT_PRICES: { [key: string]: number } = {
  'elite_1_month': 78,
  'elite_12_months': 460,
  'minvest.1month': 78,
  'minvest.12month': 460,
};

const APPLE_VERIFY_RECEIPT_URL_PRODUCTION = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_VERIFY_RECEIPT_URL_SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt";

// =================================================================
// === FUNCTION XỬ LÝ ẢNH XÁC THỰC EXNESS ===
// =================================================================
export const processVerificationImage = onObjectFinalized(
  { region: "asia-southeast1", cpu: 2, memory: "1GiB" },
  async (event) => {
    // ... (Toàn bộ logic xử lý ảnh không thay đổi)
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

      const balanceRegex = /(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})(?:\s*USD)?/;
      const idRegex = /#\s*(\d{7,})/;

      const balanceMatch = fullText.match(balanceRegex);
      const idMatch = fullText.match(idRegex);

      if (!balanceMatch || !idMatch) {
        throw new Error("Không tìm thấy đủ thông tin Số dư và ID trong ảnh.");
      }
      let balanceString = balanceMatch[1];
      const isCommaDecimal = balanceString.lastIndexOf(',') > balanceString.lastIndexOf('.');

      if (isCommaDecimal) {
        balanceString = balanceString.replace(/\./g, "").replace(',', '.');
      } else {
        balanceString = balanceString.replace(/,/g, "");
      }

      const balance = parseFloat(balanceString);

      const exnessId = idMatch[1];
      functions.logger.log(`Tìm thấy - Số dư: ${balance}, ID Exness: ${exnessId}`);

      const affiliateCheckUrl = `https://chcke.minvest.vn/api/users/check-allocation?mt4Account=${exnessId}`;
      let affiliateData: any;

      try {
        const response = await axios.get(affiliateCheckUrl);
        functions.logger.log("Dữ liệu thô từ mInvest API:", response.data);

        const firstAccountObject = response.data?.data?.[0];
        const finalData = firstAccountObject?.data?.[0];

        if (!finalData || !finalData.client_uid) {
            throw new Error("API không trả về dữ liệu hợp lệ hoặc không tìm thấy client_uid.");
        }

        affiliateData = {
          client_uid: finalData.client_uid,
          client_account: finalData.partner_account,
        };
        functions.logger.log("Kiểm tra affiliate thành công, kết quả:", affiliateData);
      } catch (apiError) {
        functions.logger.error("Lỗi khi kiểm tra affiliate:", apiError);
        throw new Error(`Tài khoản ${exnessId} không thuộc affiliate của mInvest.`);
      }

      const idDoc = await firestore
        .collection("verifiedExnessIds")
        .doc(exnessId).get();

      if (idDoc.exists) {
        throw new Error(`ID Exness ${exnessId} đã được sử dụng.`);
      }

      let tier = "demo";
      if (balance >= 500) {
        tier = "elite";
      } else if (balance >= 200) {
        tier = "vip";
      }
      functions.logger.log(`Phân quyền cho user ${userId}: ${tier}`);

      const idRef = firestore.collection("verifiedExnessIds").doc(exnessId);
      const updateData = {
        subscriptionTier: tier,
        verificationStatus: "success",
        exnessClientUid: affiliateData.client_uid,
        exnessClientAccount: exnessId,
        notificationCount: 0,
      };

      await Promise.all([
        userRef.set(updateData, { merge: true }),
        idRef.set({ userId: userId, processedAt: admin.firestore.FieldValue.serverTimestamp() }),
      ]);

      functions.logger.log("Hoàn tất phân quyền và lưu dữ liệu Exness thành công!");
      return null;
    } catch (error) {
      const errorMessage = (error as Error).message;
      functions.logger.error(`Xử lý ảnh thất bại cho user ${userId}:`, errorMessage);

      await userRef.set(
        { verificationStatus: "failed", verificationError: errorMessage },
        { merge: true }
      );
      return null;
    }
  });

// =================================================================
// === FUNCTION WEBHOOK CHO TELEGRAM BOT ===
// =================================================================
const TELEGRAM_CHAT_ID = "-1002785712406";

export const telegramWebhook = functions.https.onRequest(
  { region: "asia-southeast1", timeoutSeconds: 30, memory: "512MiB" },
  async (req: functions.https.Request, res: Response) => {
    // ... (Toàn bộ logic Telegram không thay đổi)
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
      if (message.reply_to_message && message.text) {
        const originalMessageId = message.reply_to_message.message_id;
        const updateText = message.text.toLowerCase();
        const signalQuery = await firestore.collection("signals").where("telegramMessageId", "==", originalMessageId).limit(1).get();
        if (signalQuery.empty) {
          res.status(200).send("OK. No original signal found.");
          return;
        }
        const signalDoc = signalQuery.docs[0];
        const signalRef = signalDoc.ref;
        let updatePayload: any = {};
        let logMessage = "";

        if (updateText.includes("đã khớp entry tại giá")) {
          updatePayload = { isMatched: true, result: "Matched", matchedAt: admin.firestore.FieldValue.serverTimestamp() };
          logMessage = `Tín hiệu ${signalDoc.id} đã KHỚP LỆNH (MATCHED).`;
        } else if (updateText.includes("tp1 hit")) {
            updatePayload = { result: "TP1 Hit", hitTps: admin.firestore.FieldValue.arrayUnion(1) };
            logMessage = `Tín hiệu ${signalDoc.id} đã TP1 Hit.`;
        } else if (updateText.includes("tp2 hit")) {
            updatePayload = { result: "TP2 Hit", hitTps: admin.firestore.FieldValue.arrayUnion(1, 2) };
            logMessage = `Tín hiệu ${signalDoc.id} đã TP2 Hit.`;
        } else if (updateText.includes("sl hit")) {
            updatePayload = { status: "closed", result: "SL Hit", closedAt: admin.firestore.FieldValue.serverTimestamp() };
            logMessage = `Tín hiệu ${signalDoc.id} đã SL Hit.`;
        } else if (updateText.includes("tp3 hit")) {
            updatePayload = { status: "closed", result: "TP3 Hit", hitTps: admin.firestore.FieldValue.arrayUnion(1, 2, 3), closedAt: admin.firestore.FieldValue.serverTimestamp() };
            logMessage = `Tín hiệu ${signalDoc.id} đã TP3 Hit.`;
        } else if (updateText.includes("exit tại giá") || updateText.includes("exit lệnh")) {
            updatePayload = { status: "closed", result: "Exited by Admin", closedAt: admin.firestore.FieldValue.serverTimestamp() };
            logMessage = `Tín hiệu ${signalDoc.id} đã được đóng bởi admin.`;
        } else if (updateText.includes("bỏ tín hiệu")) {
            updatePayload = { status: "closed", result: "Cancelled", closedAt: admin.firestore.FieldValue.serverTimestamp() };
            logMessage = `Tín hiệu ${signalDoc.id} đã bị hủy.`;
        }

        if (Object.keys(updatePayload).length > 0) {
          await signalRef.update(updatePayload);
          functions.logger.log(logMessage);
        }
      } else if (message.text) {
        const signalData = parseSignalMessage(message.text);
        if (signalData) {
          if (signalData.reason) {
            try {
              functions.logger.log(`Đang dịch phần giải thích: "${signalData.reason}"`);
              const [translation] = await translateClient.translate(signalData.reason, "en");
              functions.logger.log(`Dịch thành công: "${translation}"`);

              signalData.reason = {
                vi: signalData.reason,
                en: translation,
              };
            } catch (translationError) {
              functions.logger.error("Lỗi khi dịch phần giải thích:", translationError);
              signalData.reason = {
                vi: signalData.reason,
                en: "Translation failed.",
              };
            }
          }

          const batch = firestore.batch();
          const unmatchedQuery = await firestore.collection("signals").where("status", "==", "running").where("isMatched", "==", false).get();
          unmatchedQuery.forEach(doc => batch.update(doc.ref, { status: "closed", result: "Cancelled (new signal)" }));

          const oppositeType = signalData.type === 'buy' ? 'sell' : 'buy';
          const runningTpQuery = await firestore.collection("signals").where("status", "==", "running").where("type", "==", oppositeType).where("result", "in", ["TP1 Hit", "TP2 Hit"]).get();
          runningTpQuery.forEach(doc => batch.update(doc.ref, { status: "closed", result: "Exited (new signal)" }));

          const newSignalRef = firestore.collection("signals").doc();
          batch.set(newSignalRef, {
            ...signalData,
            telegramMessageId: message.message_id,
            createdAt: admin.firestore.Timestamp.fromMillis(message.date * 1000),
            status: "running",
            isMatched: false,
            result: "Not Matched",
            hitTps: [],
          });
          await batch.commit();
        }
      }
      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("Lỗi nghiêm trọng khi xử lý tin nhắn Telegram:", error);
      res.status(500).send("Internal Server Error");
    }
  }
);

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
export const verifyPurchase = onCall(
    { region: "asia-southeast1", secrets: ["APPLE_SHARED_SECRET"] },
    async (request) => {
        // ... (Logic xác thực IAP không thay đổi)
        const { productId, transactionData, platform } = request.data;
        const userId = request.auth?.uid;

        if (!userId) {
            throw new HttpsError("unauthenticated", "Người dùng chưa đăng nhập.");
        }
        if (!productId || !transactionData || !platform) {
            throw new HttpsError("invalid-argument", "Thiếu productId, transactionData hoặc platform.");
        }

        try {
            let isValid = false;
            let expiryDate: Date | null = null;
            let transactionId: string | null = null;

            if (platform === 'ios') {
                const sharedSecret = process.env.APPLE_SHARED_SECRET;
                if (!sharedSecret) {
                    functions.logger.error("Không tìm thấy APPLE_SHARED_SECRET trong môi trường runtime.");
                    throw new HttpsError("internal", "Lỗi cấu hình phía server.");
                }

                const { receiptData } = transactionData;
                const appleResponse = await verifyAppleReceipt(receiptData, sharedSecret);

                const latestReceipt = appleResponse.latest_receipt_info?.sort((a: any, b: any) =>
                    Number(b.purchase_date_ms) - Number(a.purchase_date_ms)
                )[0];

                if (latestReceipt && latestReceipt.product_id === productId) {
                    isValid = true;
                    expiryDate = new Date(Number(latestReceipt.expires_date_ms));
                    transactionId = latestReceipt.transaction_id;

                    if (transactionId) {
                        const txDoc = await firestore.collection("processedTransactions").doc(transactionId).get();
                        if (txDoc.exists) {
                            functions.logger.warn(`Giao dịch ${transactionId} đã được xử lý trước đó.`);
                            isValid = false;
                        }
                    } else {
                        isValid = false;
                    }
                }
            } else if (platform === 'android') {
                const { purchaseToken } = transactionData;
                const packageName = "com.minvest.aisignals";

                const auth = new GoogleAuth({ scopes: "https://www.googleapis.com/auth/androidpublisher" });
                const authClient = await auth.getClient();
                const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;

                const res = await authClient.request({ url });
                const purchase = res.data as any;

                if (purchase && purchase.purchaseState === 0) {
                    isValid = true;
                    expiryDate = new Date(Number(purchase.expiryTimeMillis));
                    transactionId = purchase.orderId;
                }
            }

            if (isValid && expiryDate && transactionId) {
                await upgradeUserAccount(userId, productId, expiryDate, transactionId, platform);
                return { success: true, message: "Tài khoản đã được nâng cấp thành công." };
            } else {
                throw new HttpsError("aborted", "Giao dịch không hợp lệ hoặc đã bị hủy.");
            }
        } catch (error: any) {
            functions.logger.error("Lỗi nghiêm trọng khi xác thực giao dịch:", error);
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError("internal", "Đã xảy ra lỗi trong quá trình xác thực.", error.message);
        }
    });

async function verifyAppleReceipt(receiptData: string, sharedSecret: string): Promise<any> {
  const body = {
    "receipt-data": receiptData,
    "password": sharedSecret,
    "exclude-old-transactions": true,
  };

  try {
    functions.logger.log("🍎 Đang thử xác thực với server PRODUCTION của Apple...");
    const response = await axios.post(APPLE_VERIFY_RECEIPT_URL_PRODUCTION, body);
    const data = response.data;
    functions.logger.log("🍎 Phản hồi từ server PRODUCTION:", data);

    // Apple trả về mã 21007 khi biên lai là của môi trường Sandbox
    if (data.status === 21007) {
      functions.logger.log("🕵️ Mã trạng thái 21007. Đây là biên lai Sandbox. Đang thử lại với server SANDBOX...");
      const sandboxResponse = await axios.post(APPLE_VERIFY_RECEIPT_URL_SANDBOX, body);
      functions.logger.log("🕵️ Phản hồi từ server SANDBOX:", sandboxResponse.data);

      // Kiểm tra lại trạng thái từ Sandbox
      if (sandboxResponse.data.status !== 0) {
        throw new Error(`Xác thực Sandbox thất bại với mã trạng thái: ${sandboxResponse.data.status}`);
      }
      return sandboxResponse.data;
    }

    if (data.status !== 0) {
      throw new Error(`Xác thực Production thất bại với mã trạng thái: ${data.status}`);
    }

    return data;

  } catch (error: any) {
    functions.logger.error("🔥 Lỗi nghiêm trọng khi gọi API xác thực của Apple:", {
      message: error.message,
      // Nếu có response lỗi từ axios, log nó ra
      response: error.response ? {
        status: error.response.status,
        data: error.response.data
      } : 'No response object',
    });
    throw new HttpsError("internal", "Không thể kết nối hoặc xác thực với server của Apple.");
  }
}

async function upgradeUserAccount(
  userId: string,
  productId: string,
  expiryDate: Date,
  transactionId: string,
  platform: 'ios' | 'android'
) {
  const userRef = firestore.collection("users").doc(userId);
  const amountPaid = PRODUCT_PRICES[productId] ?? 0;
  const transactionRef = userRef.collection("transactions").doc(transactionId);
  const batch = firestore.batch();

  batch.set(userRef, {
      subscriptionTier: "elite",
      subscriptionExpiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      totalPaidAmount: admin.firestore.FieldValue.increment(amountPaid),
  }, { merge: true });

  batch.set(transactionRef, {
      amount: amountPaid,
      productId: productId,
      paymentMethod: `in_app_purchase_${platform}`,
      transactionDate: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (platform === 'ios') {
      const processedTxRef = firestore.collection("processedTransactions").doc(transactionId);
      batch.set(processedTxRef, { userId, processedAt: admin.firestore.FieldValue.serverTimestamp() });
  }

  await batch.commit();
}

// =================================================================
// === HỆ THỐNG GỬI THÔNG BÁO ===
// =================================================================
function isGoldenHour(): boolean {
  const now = new Date();
  const vietnamTime = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Ho_Chi_Minh" }));
  const hour = vietnamTime.getHours();
  return hour >= 8 && hour < 17;
}

const sendAndStoreNotifications = async (
    usersData: { id: string; token?: string; lang: string }[],
    payload: any
) => {
    if (usersData.length === 0) return;

    const batchStore = firestore.batch();
    const notificationData = {
        ...payload,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
    };
    usersData.forEach((user) => {
        const notificationRef = firestore.collection("users").doc(user.id).collection("notifications").doc();
        batchStore.set(notificationRef, notificationData);
    });

    const messages: admin.messaging.Message[] = [];

    usersData.forEach((user) => {
        if (user.token) {
            const lang = user.lang as "vi" | "en";
            const title = payload.title_loc[lang];
            const body = payload.body_loc[lang];

            messages.push({
                token: user.token,
                data: {
                    ...payload,
                    title,
                    body,
                },
                android: { priority: "high" },
                apns: {
                    headers: { "apns-priority": "10" },
                    payload: { aps: { "content-available": 1 } },
                },
            });
        }
    });

    if (messages.length > 0) {
        await admin.messaging().sendEach(messages);
    }

    await batchStore.commit();
};

async function triggerNotifications(payload: any) {
    const isGolden = isGoldenHour();
    const allEligibleUsersDocs: admin.firestore.DocumentSnapshot[] = [];

    const eliteQuery = firestore.collection("users").where("subscriptionTier", "==", "elite").get();
    const timeRestrictedPromises: Promise<admin.firestore.QuerySnapshot>[] = [];

    if (isGolden) {
        const vipQuery = firestore.collection("users").where("subscriptionTier", "==", "vip").get();
        const demoQuery = firestore.collection("users").where("subscriptionTier", "==", "demo").where("notificationCount", "<", 8).get();
        timeRestrictedPromises.push(vipQuery, demoQuery);
    }

    const [eliteSnapshot, ...timeRestrictedSnapshots] = await Promise.all([eliteQuery, ...timeRestrictedPromises]);
    eliteSnapshot.forEach((doc) => allEligibleUsersDocs.push(doc));
    timeRestrictedSnapshots.forEach((snapshot) => snapshot.forEach((doc) => allEligibleUsersDocs.push(doc)));

    if (allEligibleUsersDocs.length === 0) {
        functions.logger.log("Không có người dùng nào đủ điều kiện nhận thông báo.");
        return;
    }

    type UserNotificationData = {
        id: string;
        token?: string;
        lang: "vi" | "en";
        tier: string;
    };

    const usersData = allEligibleUsersDocs
        .map((doc): UserNotificationData | null => {
            const data = doc.data();
            if (!data) {
                return null;
            }
            return {
                id: doc.id,
                token: data.activeSession?.fcmToken,
                lang: data.languageCode === "en" ? "en" : "vi",
                tier: data.subscriptionTier,
            };
        })
        .filter((user): user is UserNotificationData => user !== null);

    await sendAndStoreNotifications(usersData, payload);

    const demoUsersToUpdate = usersData
        .filter((user) => user.tier === "demo")
        .map((user) => user.id);

    if (demoUsersToUpdate.length > 0) {
        const batchUpdate = firestore.batch();
        demoUsersToUpdate.forEach((userId) => {
            const userRef = firestore.collection("users").doc(userId);
            batchUpdate.update(userRef, { notificationCount: admin.firestore.FieldValue.increment(1) });
        });
        await batchUpdate.commit();
    }
}

export const onNewSignalCreated = onDocumentCreated({ document: "signals/{signalId}", region: "asia-southeast1", memory: "256MiB" }, async (event) => {
    const signalData = event.data?.data();
    if (!signalData) return;

    const localizedPayload = await getLocalizedPayload(
        "new_signal",
        signalData.type.toUpperCase(),
        signalData.symbol,
        signalData.entryPrice,
        signalData.stopLoss
    );

    const finalPayload = {
      type: "new_signal",
      signalId: event.params.signalId,
      ...localizedPayload,
    };

    await triggerNotifications(finalPayload);
});

export const onSignalUpdated = onDocumentUpdated({ document: "signals/{signalId}", region: "asia-southeast1", memory: "256MiB" }, async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    let notificationType: string | null = null;
    let payloadArgs: (string | number)[] = [];
    const { symbol, type, entryPrice } = afterData;

    if (beforeData.isMatched === false && afterData.isMatched === true) {
        notificationType = "signal_matched";
        payloadArgs = [type.toUpperCase(), symbol, entryPrice];
    } else if (beforeData.result !== afterData.result) {
        switch(afterData.result) {
            case "TP1 Hit":
                notificationType = "tp1_hit";
                payloadArgs = [type.toUpperCase(), symbol];
                break;
            case "TP2 Hit":
                notificationType = "tp2_hit";
                payloadArgs = [type.toUpperCase(), symbol];
                break;
            case "TP3 Hit":
                notificationType = "tp3_hit";
                payloadArgs = [type.toUpperCase(), symbol];
                break;
            case "SL Hit":
                notificationType = "sl_hit";
                payloadArgs = [type.toUpperCase(), symbol];
                break;
        }
    }

    if (notificationType) {
        const localizedPayload = await getLocalizedPayload(
            notificationType as any,
            ...payloadArgs
        );
        const finalPayload = {
            type: notificationType,
            signalId: event.params.signalId,
            ...localizedPayload
        };
        await triggerNotifications(finalPayload);
    }
});

// =================================================================
// === FUNCTION QUẢN LÝ TIỆN ÍCH KHÁC ===
// =================================================================
export const manageUserSession = onCall({ region: "asia-southeast1" }, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const uid = request.auth.uid;
  const newDeviceId = request.data.deviceId;
  const newFcmToken = request.data.fcmToken;

  if (!newDeviceId) {
    throw new functions.https.HttpsError("invalid-argument", "The function must be called with a 'deviceId' argument.");
  }

  const userDocRef = firestore.collection("users").doc(uid);
  try {
    await firestore.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userDocRef);

      if (!userDoc.exists) {
        functions.logger.error(`manageUserSession được gọi cho user ${uid} nhưng document không tồn tại.`);
        return;
      }

      const userData = userDoc.data();
      const currentSession = userData?.activeSession;

      if (currentSession && currentSession.deviceId && currentSession.deviceId !== newDeviceId && currentSession.fcmToken) {
        const message = {
          token: currentSession.fcmToken,
          data: { action: "FORCE_LOGOUT" },
          apns: { headers: { "apns-priority": "10" }, payload: { aps: { "content-available": 1 } } },
          android: { priority: "high" as const },
        };
        try {
          await admin.messaging().send(message);
        } catch (error) {
          functions.logger.error(`Error sending FORCE_LOGOUT to ${currentSession.fcmToken}:`, error);
        }
      }

      const newSessionData = {
        deviceId: newDeviceId,
        fcmToken: newFcmToken,
        loginAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      transaction.update(userDocRef, { activeSession: newSessionData });
    });
    return { status: "success", message: "Session managed successfully." };
  } catch (error) {
    functions.logger.error("Error in manageUserSession transaction:", error);
    throw new functions.https.HttpsError("internal", "An error occurred while managing the user session.");
  }
});

export const downgradeUsersToFree = onCall({ region: "asia-southeast1" }, async (request) => {
    const adminUid = request.auth?.uid;
    if (!adminUid) {
        throw new functions.https.HttpsError("unauthenticated", "Bạn phải đăng nhập để thực hiện hành động này.");
    }
    const adminUserDoc = await firestore.collection("users").doc(adminUid).get();
    if (adminUserDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Bạn không có quyền thực hiện hành động này.");
    }

    const { userIds, reason } = request.data;
    if (!userIds || !Array.isArray(userIds)) {
        throw new functions.https.HttpsError("invalid-argument", "Dữ liệu 'userIds' gửi lên không hợp lệ.");
    }

    const hasCustomReason = reason && typeof reason === 'string' && reason.trim().length > 0;

    const reasonForNotification = {
        vi: hasCustomReason ? reason : "Tài khoản của bạn đã được chuyển về gói Free do vi phạm chính sách. Vui lòng đăng nhập lại.",
        en: hasCustomReason ? reason : "Your account has been downgraded to the Free plan due to a policy violation. Please log in again.",
    };

    const batch = firestore.batch();
    const usersToNotify: { token: string; lang: string }[] = [];

    for (const userId of userIds) {
        if (userId === adminUid) continue;

        const userRef = firestore.collection("users").doc(userId);

        const updateData = {
            subscriptionTier: 'free',
            requiresDowngradeAcknowledgement: true,
            downgradeReason: hasCustomReason ? reason : "Tài khoản của bạn đã được quản trị viên chuyển về gói Free.",
            isSuspended: admin.firestore.FieldValue.delete(),
            suspensionReason: admin.firestore.FieldValue.delete()
        };
        batch.update(userRef, updateData);

        const userDoc = await userRef.get();
        const userData = userDoc.data();
        const fcmToken = userData?.activeSession?.fcmToken;
        if (fcmToken) {
            usersToNotify.push({
                token: fcmToken,
                lang: userData?.languageCode === 'en' ? 'en' : 'vi'
            });
        }
    }

    await batch.commit();

    if (usersToNotify.length > 0) {
        const promises = usersToNotify.map(user => {
            const message = {
                token: user.token,
                data: {
                    action: "FORCE_LOGOUT",
                    reason: user.lang === 'en' ? reasonForNotification.en : reasonForNotification.vi
                },
                apns: { headers: { "apns-priority": "10" }, payload: { aps: { "content-available": 1 } } },
                android: { priority: "high" as const },
            };
            return admin.messaging().send(message).catch(err => {
                functions.logger.error(`Lỗi gửi thông báo hạ cấp tới ${user.token}`, err);
            });
        });
        await Promise.all(promises);
    }

    return { status: "success", message: `Đã hạ cấp thành công ${userIds.length} tài khoản về Free.` };
});

export const resetDemoNotificationCounters = onSchedule({ schedule: "1 0 * * *", timeZone: "Asia/Ho_Chi_Minh", region: "asia-southeast1" }, async () => {
    const demoUsersSnapshot = await firestore.collection("users").where("subscriptionTier", "==", "demo").get();
    if (demoUsersSnapshot.empty) return;
    const batch = firestore.batch();
    demoUsersSnapshot.forEach(doc => batch.update(doc.ref, { notificationCount: 0 }));
    await batch.commit();
});

async function deleteCollection(db: admin.firestore.Firestore, collectionPath: string, batchSize: number) {
    const collectionRef = db.collection(collectionPath);
    const query = collectionRef.orderBy('__name__').limit(batchSize);

    return new Promise((resolve, reject) => {
        deleteQueryBatch(db, query, resolve).catch(reject);
    });
}

async function deleteQueryBatch(db: admin.firestore.Firestore, query: admin.firestore.Query, resolve: (value: unknown) => void) {
    const snapshot = await query.get();
    if (snapshot.size === 0) {
        resolve(true);
        return;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    process.nextTick(() => {
        deleteQueryBatch(db, query, resolve);
    });
}

export const deleteUserAccount = onCall({ region: "asia-southeast1" }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new HttpsError("unauthenticated", "Yêu cầu phải được xác thực.");
    }
    functions.logger.log(`Bắt đầu quá trình xóa cho người dùng: ${uid}`);
    try {
        await deleteCollection(firestore, `users/${uid}/notifications`, 50);
        functions.logger.log(`Đã xóa subcollection 'notifications' cho user ${uid}`);

        await deleteCollection(firestore, `users/${uid}/transactions`, 50);
        functions.logger.log(`Đã xóa subcollection 'transactions' cho user ${uid}`);

        await firestore.collection("users").doc(uid).delete();
        functions.logger.log(`Đã xóa document chính của user ${uid}`);

        const exnessIdQuery = await firestore.collection("verifiedExnessIds").where("userId", "==", uid).limit(1).get();
        if (!exnessIdQuery.empty) {
            await exnessIdQuery.docs[0].ref.delete();
            functions.logger.log(`Đã xóa 'verifiedExnessIds' cho user ${uid}`);
        }

        await admin.auth().deleteUser(uid);
        functions.logger.log(`Hoàn tất: Đã xóa người dùng khỏi Firebase Auth: ${uid}`);

        return { success: true, message: "Tài khoản và dữ liệu đã được xóa thành công." };

    } catch (error) {
        functions.logger.error(`Lỗi khi xóa người dùng ${uid}:`, error);
        throw new HttpsError("internal", "Không thể xóa tài khoản, vui lòng thử lại sau.", error);
    }
});