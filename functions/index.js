const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
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

// ══════════════════════════════════════════════════════════════════════════════
// 가족 그룹 캘린더 알림
// ══════════════════════════════════════════════════════════════════════════════

// 펫 소유자의 가족 그룹 전체 멤버 ID 반환 (그룹 없으면 소유자만)
async function getGroupMemberIds(ownerId) {
  if (!ownerId) return [];
  const ownerDoc = await db.collection('users').doc(ownerId).get();
  if (!ownerDoc.exists) return [ownerId];

  const groupId = ownerDoc.data().familyGroupId;
  if (!groupId) return [ownerId];

  const groupDoc = await db.collection('familyGroups').doc(groupId).get();
  if (!groupDoc.exists) return [ownerId];

  const ids = groupDoc.data().memberIds || [];
  return ids.length > 0 ? ids : [ownerId];
}

// petId로 펫 문서를 읽어 (petName, memberIds) 반환
async function getPetAndMembers(petId) {
  const petDoc = await db.collection('pets').doc(petId).get();
  if (!petDoc.exists) return null;
  const petData = petDoc.data();
  const memberIds = await getGroupMemberIds(petData.userId);
  return { petName: petData.name || '', memberIds };
}

// 가족 그룹 전체에 캘린더 이벤트 FCM 전송
async function sendCalendarPush(calDoc, settingKey, title, buildBody) {
  const d = calDoc.data();
  if (!d.petId) return;

  const info = await getPetAndMembers(d.petId);
  if (!info) return;

  const body = buildBody(info.petName);
  await Promise.all(
    info.memberIds.map((id) =>
      sendPush(id, settingKey, title, body, {
        type: settingKey,
        calDocId: calDoc.id,
        petId: d.petId,
      }),
    ),
  );
}

// KST Date 변환 헬퍼
function toKST(date) {
  return new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Seoul' }));
}

// ── 투약/진료/접종 알림 (매분 실행) ──────────────────────────────────────────
// Cloud Scheduler 최소 단위 1분 → 65초 윈도우(5초 버퍼)로 누락 방지
const WINDOW_MS = 65 * 1000;

exports.sendGroupCalendarNotifications = onSchedule(
  { schedule: '* * * * *', timeZone: 'Asia/Seoul', timeoutSeconds: 120 },
  async () => {
    const now = new Date();
    const kstNow = toKST(now);

    // ── 1. 비반복 투약: date가 현재 윈도우 내 ──────────────────────────────
    const medWindowStart = Timestamp.fromDate(new Date(now.getTime() - WINDOW_MS));
    const medWindowEnd = Timestamp.fromDate(now);

    const medSnap = await db.collection('calendars')
      .where('date', '>=', medWindowStart)
      .where('date', '<=', medWindowEnd)
      .get();

    for (const doc of medSnap.docs) {
      const d = doc.data();
      if (d.type !== 'medication') continue;
      if (d.repeatDays && d.repeatDays.length > 0) continue; // 반복은 아래에서 처리

      await sendCalendarPush(
        doc, 'medication', '투약 알림',
        (petName) => `${petName} · ${d.title || '투약'} 시간이에요`,
      );
    }

    // ── 2. 반복 투약: 오늘 요일(Dart 기준) + 현재 시각(시:분) 매칭 ─────────
    // Dart weekday: Mon=1 ... Sat=6, Sun=7
    const jsDay = kstNow.getDay(); // JS: Sun=0, Mon=1 ... Sat=6
    const dartWeekday = jsDay === 0 ? 7 : jsDay;
    const currentH = kstNow.getHours();
    const currentM = kstNow.getMinutes();

    // array-contains 단일 필드 쿼리 → 자동 인덱스로 동작
    const repeatSnap = await db.collection('calendars')
      .where('repeatDays', 'array-contains', dartWeekday)
      .get();

    for (const doc of repeatSnap.docs) {
      const d = doc.data();
      if (d.type !== 'medication') continue;

      // 종료일 초과 건너뜀
      if (d.endDate) {
        const endKST = toKST(d.endDate.toDate());
        const todayStart = new Date(kstNow.getFullYear(), kstNow.getMonth(), kstNow.getDate());
        if (endKST < todayStart) continue;
      }

      // 시각 매칭 (date 필드의 HH:mm과 현재 KST HH:mm 비교)
      const dateKST = toKST(d.date.toDate());
      if (dateKST.getHours() !== currentH || dateKST.getMinutes() !== currentM) continue;

      await sendCalendarPush(
        doc, 'medication', '투약 알림',
        (petName) => `${petName} · ${d.title || '투약'} 시간이에요`,
      );
    }

    // ── 3. 진료/접종: 1시간 전 · 하루 전 · 3일 전 ─────────────────────────
    const apptOffsets = [
      { ms: 1 * 60 * 60 * 1000, label: '1시간 후에' },
      { ms: 24 * 60 * 60 * 1000, label: '내일' },
      { ms: 3 * 24 * 60 * 60 * 1000, label: '3일 후에' },
    ];

    for (const { ms, label } of apptOffsets) {
      const targetMs = now.getTime() + ms;
      const start = Timestamp.fromDate(new Date(targetMs - WINDOW_MS));
      const end = Timestamp.fromDate(new Date(targetMs));

      const apptSnap = await db.collection('calendars')
        .where('date', '>=', start)
        .where('date', '<=', end)
        .get();

      for (const doc of apptSnap.docs) {
        const d = doc.data();
        if (d.type !== 'appointment' && d.type !== 'vaccination') continue;

        const typeLabel = d.type === 'appointment' ? '진료' : '접종';
        await sendCalendarPush(
          doc, 'appointment', `${typeLabel} 알림`,
          (petName) => `${petName} · ${d.title || typeLabel} 일정이 ${label} 있어요`,
        );
      }
    }

    console.log('[sendGroupCalendarNotifications] 완료');
  },
);

// ── 생일 알림 (매일 오전 9시 KST) ─────────────────────────────────────────
// 내일 생일인 펫을 찾아 가족 그룹 전체에 FCM 전송
exports.sendBirthdayNotifications = onSchedule(
  { schedule: '0 9 * * *', timeZone: 'Asia/Seoul', timeoutSeconds: 120 },
  async () => {
    const kstNow = toKST(new Date());

    // 내일 (KST)
    const tomorrow = new Date(kstNow);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowMonth = tomorrow.getMonth() + 1; // 1~12
    const tomorrowDay = tomorrow.getDate();

    const petsSnap = await db.collection('pets').get();

    for (const petDoc of petsSnap.docs) {
      const d = petDoc.data();
      if (!d.birthDate || d.birthUnknown === true) continue;

      const birthKST = toKST(d.birthDate.toDate());
      if (birthKST.getMonth() + 1 !== tomorrowMonth || birthKST.getDate() !== tomorrowDay) {
        continue;
      }

      const ownerId = d.userId;
      if (!ownerId) continue;

      const memberIds = await getGroupMemberIds(ownerId);
      const petName = d.name || '반려동물';

      await Promise.all(
        memberIds.map((id) =>
          sendPush(id, 'birthday', '생일 알림', `${petName}의 생일이 내일이에요!`, {
            type: 'birthday',
            petId: petDoc.id,
          }),
        ),
      );
    }

    console.log('[sendBirthdayNotifications] 완료');
  },
);
