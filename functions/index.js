const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// 수신자의 FCM 토큰과 알림 설정 확인 후 전송
async function sendPush(recipientId, settingKey, title, body, data) {
  console.log(`[sendPush] 수신자 조회 시작 - recipientId: ${recipientId}, settingKey: ${settingKey}`);

  const userDoc = await db.collection('users').doc(recipientId).get();
  if (!userDoc.exists) {
    console.log(`[sendPush] 수신자 문서 없음 - recipientId: ${recipientId}`);
    return;
  }

  const userData = userDoc.data();
  const settings = userData.notificationSettings || {};

  // 해당 알림 설정이 꺼져 있으면 스킵
  if (settings[settingKey] === false) {
    console.log(`[sendPush] 알림 설정 꺼져 있음 - recipientId: ${recipientId}, settingKey: ${settingKey}`);
    return;
  }

  const token = userData.fcmToken;
  console.log(`[sendPush] FCM 토큰 확인 - recipientId: ${recipientId}, token: ${token ? token.slice(0, 20) + '...' : 'null'}`);
  if (!token) {
    console.log(`[sendPush] FCM 토큰 없음 - recipientId: ${recipientId}`);
    return;
  }

  console.log(`[sendPush] 알림 전송 시작 - title: "${title}", body: "${body}"`);
  try {
    await messaging.send({
      token,
      data: {
        ...(data || {}),
        title,
        body,
      },
      android: {
        priority: 'high',
      },
    });
    console.log(`[sendPush] 알림 전송 성공 - recipientId: ${recipientId}`);
  } catch (err) {
    console.error(`[sendPush] 알림 전송 실패 - recipientId: ${recipientId}, error: ${err.code} ${err.message}`);
    // 토큰 만료/유효하지 않으면 Firestore에서 제거
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      console.log(`[sendPush] 만료된 FCM 토큰 제거 - recipientId: ${recipientId}`);
      await db.collection('users').doc(recipientId).update({ fcmToken: null });
    }
  }
}

// 새 댓글/답글 알림
exports.onNewComment = onDocumentCreated('comments/{commentId}', async (event) => {
  const commentId = event.params.commentId;
  const comment = event.data.data();
  const { postId, userId: commenterId, nickname, parentId } = comment;

  console.log(`[onNewComment] 트리거 시작 - commentId: ${commentId}, postId: ${postId}, commenterId: ${commenterId}, parentId: ${parentId || 'null'}`);

  if (parentId) {
    // 답글: 부모 댓글 작성자에게 알림
    console.log(`[onNewComment] 답글 감지 - 부모 댓글 조회 시작, parentId: ${parentId}`);
    const parentDoc = await db.collection('comments').doc(parentId).get();
    if (!parentDoc.exists) {
      console.log(`[onNewComment] 부모 댓글 없음 - parentId: ${parentId}`);
      return;
    }

    const recipientId = parentDoc.data().userId;
    console.log(`[onNewComment] 부모 댓글 작성자 확인 - recipientId: ${recipientId}`);
    if (recipientId === commenterId) {
      console.log(`[onNewComment] 자기 자신에게 답글 - 알림 스킵`);
      return;
    }

    await sendPush(
      recipientId,
      'reply',
      '답글 알림',
      `${nickname}님이 내 댓글에 답글을 남겼어요`,
      { type: 'reply', postId },
    );
  } else {
    // 댓글: 게시글 작성자에게 알림
    console.log(`[onNewComment] 댓글 감지 - 게시글 조회 시작, postId: ${postId}`);
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      console.log(`[onNewComment] 게시글 없음 - postId: ${postId}`);
      return;
    }

    const recipientId = postDoc.data().userId;
    console.log(`[onNewComment] 게시글 작성자 확인 - recipientId: ${recipientId}`);
    if (recipientId === commenterId) {
      console.log(`[onNewComment] 자기 게시글에 자기 댓글 - 알림 스킵`);
      return;
    }

    await sendPush(
      recipientId,
      'comment',
      '댓글 알림',
      `${nickname}님이 댓글을 남겼어요`,
      { type: 'comment', postId },
    );
  }

  console.log(`[onNewComment] 트리거 완료 - commentId: ${commentId}`);
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

// 유저 블랙리스트 처리 + 해당 유저의 모든 게시글 isBlacklisted: true 일괄 적용
async function blacklistUser(userId) {
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists || userDoc.data().isBlacklisted) return;

  await userRef.update({ isBlacklisted: true });
  console.log(`[blacklistUser] 유저 블랙리스트 처리 완료 - userId: ${userId}`);

  // 해당 유저의 게시글 전체에 isBlacklisted: true 일괄 적용 (Firestore 배치 최대 500건)
  const postsSnap = await db.collection('posts').where('userId', '==', userId).get();
  if (postsSnap.empty) return;

  const chunks = [];
  for (let i = 0; i < postsSnap.docs.length; i += 500) {
    chunks.push(postsSnap.docs.slice(i, i + 500));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach((doc) => batch.update(doc.ref, { isBlacklisted: true }));
    await batch.commit();
  }
  console.log(`[blacklistUser] 게시글 ${postsSnap.size}건 isBlacklisted 처리 완료 - userId: ${userId}`);
}

// 게시글 신고 누적 5회 → 작성자 자동 블랙리스트
exports.onPostReported = onDocumentUpdated('posts/{postId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // reportCount가 5 미만에서 5 이상으로 처음 넘는 시점에만 처리
  if ((before.reportCount ?? 0) >= 5 || (after.reportCount ?? 0) < 5) return;

  const userId = after.userId;
  if (!userId) return;

  console.log(`[onPostReported] 신고 5회 도달 - postId: ${event.params.postId}, userId: ${userId}`);
  await blacklistUser(userId);
});

// 댓글 신고 누적 5회 → 작성자 자동 블랙리스트
exports.onCommentReported = onDocumentUpdated('comments/{commentId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if ((before.reportCount ?? 0) >= 5 || (after.reportCount ?? 0) < 5) return;

  const userId = after.userId;
  if (!userId) return;

  console.log(`[onCommentReported] 신고 5회 도달 - commentId: ${event.params.commentId}, userId: ${userId}`);
  await blacklistUser(userId);
});

// 문의 답변 알림
exports.onSuggestionReply = onDocumentUpdated('suggestions/{suggestionId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // reply가 새로 설정된 경우에만 전송
  if (before.reply || !after.reply) return;

  const recipientId = after.userId;
  if (!recipientId) return;

  await sendPush(
    recipientId,
    'suggestionReply',
    '문의 답변',
    '문의하신 내용에 답변이 달렸어요',
    { type: 'suggestionReply' },
  );
});
