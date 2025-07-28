import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import * as crypto from "crypto";
import * as querystring from "qs";


// =================================================================
// === KHỞI TẠO CÁC DỊCH VỤ ===
// =================================================================
admin.initializeApp();
const firestore = admin.firestore();
const visionClient = new ImageAnnotatorClient();


// =================================================================
// === FUNCTION XỬ LÝ ẢNH XÁC THỰC EXNESS (TỰ ĐỘNG KÍCH HOẠT) ===
// =================================================================
export const processVerificationImage = onObjectFinalized(
  // Cấu hình function để chạy ở khu vực gần bạn và có CPU mạnh mẽ
  { region: "asia-southeast1", cpu: 2 },
  async (event) => {
    const fileBucket = event.data.bucket;
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    // 1. Lọc các file không liên quan
    if (!filePath || !filePath.startsWith("verification_images/")) {
      functions.logger.log(`Bỏ qua file không liên quan: ${filePath}`);
      return null;
    }
    if (!contentType || !contentType.startsWith("image/")) {
      functions.logger.log(`Bỏ qua file không phải ảnh: ${contentType}`);
      return null;
    }

    // Lấy User ID từ tên file (ví dụ: verification_images/USER_ID.jpg)
    const userId = filePath.split("/")[1].split(".")[0];
    functions.logger.log(`Bắt đầu xử lý ảnh cho user: ${userId}`);

    const userRef = firestore.collection("users").doc(userId);

    try {
      // Xóa trạng thái xác thực cũ để chuẩn bị cho lần mới
      await userRef.update({
        verificationStatus: admin.firestore.FieldValue.delete(),
        verificationError: admin.firestore.FieldValue.delete(),
      });

      // 2. Dùng Vision AI để đọc văn bản từ ảnh
      const [result] = await visionClient.textDetection(
        `gs://${fileBucket}/${filePath}`
      );
      const fullText = result.fullTextAnnotation?.text;

      if (!fullText) {
        throw new Error("Không đọc được văn bản nào từ ảnh.");
      }
      functions.logger.log("Văn bản đọc được:", fullText);

      // 3. Phân tích văn bản để tìm Số dư và ID Exness
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

      // 4. Kiểm tra xem ID Exness này đã được dùng chưa
      const idDoc = await firestore
        .collection("verifiedExnessIds")
        .doc(exnessId).get();

      if (idDoc.exists) {
        throw new Error(`ID Exness ${exnessId} đã được sử dụng.`);
      }

      // 5. Gán quyền dựa trên số dư
      let tier = "demo";
      if (balance >= 500) {
        tier = "elite";
      } else if (balance >= 200) {
        tier = "vip";
      }

      functions.logger.log(`Phân quyền cho user ${userId}: ${tier}`);

      // 6. Cập nhật quyền cho user và lưu lại ID đã dùng
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

      // Cập nhật trạng thái lỗi cho user trên Firestore
      await userRef.set(
        {verificationStatus: "failed", verificationError: errorMessage},
        {merge: true}
      );
      return null;
    }
  });


// =================================================================
// === FUNCTION TẠO LINK THANH TOÁN VNPAY
// =================================================================
const TMN_CODE = "EZTRTEST";
const HASH_SECRET = "DGTXQMK0DF9NZTZBH63RV3AM3E53K8AX";
const VNP_URL = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";
const RETURN_URL = "https://sandbox.vnpayment.vn/tryitnow/Home/VnPayReturn";
const USD_TO_VND_RATE = 25500;

export const createVnpayOrder = functions.https.onCall(async (request) => {
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

  functions.logger.info("Các tham số VNPay đã sắp xếp:", vnpParams);

  const signData = querystring.stringify(vnpParams, {encode: false});
  const hmac = crypto.createHmac("sha512", HASH_SECRET);
  const signed = hmac.update(Buffer.from(signData, "utf-8")).digest("hex");
  vnpParams["vnp_SecureHash"] = signed;

  const paymentUrl = VNP_URL + "?" + querystring.stringify(vnpParams, {encode: true});

  functions.logger.info("URL thanh toán được tạo:", paymentUrl);

  return {paymentUrl: paymentUrl};
});