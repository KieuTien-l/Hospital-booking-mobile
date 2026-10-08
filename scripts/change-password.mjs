import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const serviceAccount = JSON.parse(
  await readFile(resolve('./service-account.json'), 'utf8')
);

initializeApp({ credential: cert(serviceAccount) });
const auth = getAuth();

const targetEmail = 'dalieuthammyda-155-hxtBTUtmKklwmLm6RcJH@bookinghospitalapp.local';
const newPassword = 'password123'; // Đổi mật khẩu thành password123

async function run() {
  try {
    const userRecord = await auth.getUserByEmail(targetEmail);
    console.log(`Đã tìm thấy user: ${userRecord.uid}`);
    
    await auth.updateUser(userRecord.uid, {
      password: newPassword,
    });
    
    console.log(`✅ Đã đổi mật khẩu thành công cho ${targetEmail} thành: ${newPassword}`);
  } catch (error) {
    console.error('Lỗi:', error.message);
  }
}

run();
