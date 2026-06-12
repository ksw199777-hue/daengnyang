const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// 수신자의 FCM 토큰과 알림 설정 확인 후 전송
async function sendPush(recipientId, settingKey, title, body, data) {
  const userDoc = await db.collection('users').doc(recipientId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const settings = userData.notificationSettings || {};

  // 해당 알림 설정이 꺼져 있으면 스킵
  if (settings[settingKey] === false) return;

  const token = userData.fcmToken;
  if (!token) return;

  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: data || {},
      android: {
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
        },
      },
    });
  } catch (err) {
    // 토큰 만료/유효하지 않으면 Firestore에서 제거
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      await db.collection('users').doc(recipientId).update({ fcmToken: null });
    }
  }
}

// 새 댓글/답글 알림
exports.onNewComment = onDocumentCreated('comments/{commentId}', async (event) => {
  const comment = event.data.data();
  const { postId, userId: commenterId, nickname, parentId } = comment;

  if (parentId) {
    // 답글: 부모 댓글 작성자에게 알림
    const parentDoc = await db.collection('comments').doc(parentId).get();
    if (!parentDoc.exists) return;

    const recipientId = parentDoc.data().userId;
    if (recipientId === commenterId) return; // 자기 자신 제외

    await sendPush(
      recipientId,
      'reply',
      '답글 알림',
      `${nickname}님이 내 댓글에 답글을 남겼어요`,
      { type: 'reply', postId },
    );
  } else {
    // 댓글: 게시글 작성자에게 알림
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;

    const recipientId = postDoc.data().userId;
    if (recipientId === commenterId) return; // 자기 자신 제외

    await sendPush(
      recipientId,
      'comment',
      '댓글 알림',
      `${nickname}님이 댓글을 남겼어요`,
      { type: 'comment', postId },
    );
  }
});

// 새 채팅 메시지 알림
exports.onNewMessage = onDocumentCreated('messages/{messageId}', async (event) => {
  const message = event.data.data();
  const { chatId, senderId, content, isImage } = message;

  const chatDoc = await db.collection('chats').doc(chatId).get();
  if (!chatDoc.exists) return;

  const participants = chatDoc.data().participants || [];
  const recipientId = participants.find((id) => id !== senderId);
  if (!recipientId) return;

  // 발신자 닉네임
  const senderDoc = await db.collection('users').doc(senderId).get();
  const senderNickname = senderDoc.exists
    ? (senderDoc.data().nickname || '알 수 없음')
    : '알 수 없음';

  await sendPush(
    recipientId,
    'chat',
    senderNickname,
    isImage ? '사진을 보냈어요' : content,
    { type: 'chat', chatId },
  );
});
