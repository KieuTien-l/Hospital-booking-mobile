import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { executeAdminCommand } from './commands.js';
import { AdminError } from './policy.js';

initializeApp();
export const adminCommand = onCall({ region: 'asia-southeast1', timeoutSeconds: 60, maxInstances: 5 }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập.');
  try {
    return await executeAdminCommand(getFirestore(), getAuth(), request.auth.uid, request.data);
  } catch (error) {
    if (error instanceof AdminError) throw new HttpsError(error.code, error.message);
    // Never include patient data, request payloads or credentials in the response.
    console.error('adminCommand failed', { code: error.code || 'unknown' });
    throw new HttpsError('internal', 'Không thể hoàn tất thao tác. Giữ nguyên yêu cầu để thử lại hoặc kiểm tra nhật ký.');
  }
});
