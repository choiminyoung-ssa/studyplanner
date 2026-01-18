#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import admin from 'firebase-admin';
import * as dotenv from 'dotenv';

dotenv.config();

// Firebase 초기화
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// MCP 서버 생성
const server = new Server(
  {
    name: 'studyplanner-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 도구 목록 제공
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'add_daily_plan',
        description: '일일 학습 계획을 추가합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            date: {
              type: 'string',
              description: '날짜 (YYYY-MM-DD 형식)'
            },
            title: {
              type: 'string',
              description: '계획 제목'
            },
            subject: {
              type: 'string',
              description: '과목 (선택사항)',
              default: ''
            },
            notes: {
              type: 'string',
              description: '메모 (선택사항)',
              default: ''
            }
          },
          required: ['userId', 'date', 'title']
        }
      },
      {
        name: 'add_weekly_plan',
        description: '주간 학습 계획을 추가합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            date: {
              type: 'string',
              description: '날짜 (YYYY-MM-DD 형식)'
            },
            title: {
              type: 'string',
              description: '계획 제목'
            },
            subject: {
              type: 'string',
              description: '과목 (선택사항)',
              default: ''
            },
            pageRanges: {
              type: 'array',
              items: { type: 'string' },
              description: '페이지 범위 (예: ["45-67", "100-120"])',
              default: []
            },
            notes: {
              type: 'string',
              description: '메모 (선택사항)',
              default: ''
            }
          },
          required: ['userId', 'date', 'title']
        }
      },
      {
        name: 'add_monthly_goal',
        description: '월간 목표를 추가합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            month: {
              type: 'string',
              description: '월 (YYYY-MM 형식)'
            },
            title: {
              type: 'string',
              description: '목표 제목'
            },
            subject: {
              type: 'string',
              description: '과목 (선택사항)',
              default: ''
            },
            endDate: {
              type: 'string',
              description: '목표 종료일 (YYYY-MM-DD 형식, 선택사항)'
            },
            priority: {
              type: 'number',
              description: '우선순위 (1: 높음, 2: 중간, 3: 낮음)',
              default: 2,
              enum: [1, 2, 3]
            },
            notes: {
              type: 'string',
              description: '메모 (선택사항)',
              default: ''
            }
          },
          required: ['userId', 'month', 'title']
        }
      },
      {
        name: 'get_daily_plans',
        description: '특정 날짜의 일일 계획을 조회합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            date: {
              type: 'string',
              description: '날짜 (YYYY-MM-DD 형식)'
            }
          },
          required: ['userId', 'date']
        }
      },
      {
        name: 'get_weekly_plans',
        description: '특정 주의 주간 계획을 조회합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            startDate: {
              type: 'string',
              description: '주 시작일 (YYYY-MM-DD 형식)'
            },
            endDate: {
              type: 'string',
              description: '주 종료일 (YYYY-MM-DD 형식)'
            }
          },
          required: ['userId', 'startDate', 'endDate']
        }
      },
      {
        name: 'get_monthly_goals',
        description: '특정 월의 월간 목표를 조회합니다',
        inputSchema: {
          type: 'object',
          properties: {
            userId: {
              type: 'string',
              description: '사용자 ID'
            },
            month: {
              type: 'string',
              description: '월 (YYYY-MM 형식)'
            }
          },
          required: ['userId', 'month']
        }
      },
      {
        name: 'complete_plan',
        description: '계획을 완료 상태로 변경합니다',
        inputSchema: {
          type: 'object',
          properties: {
            collection: {
              type: 'string',
              description: '컬렉션 이름 (dailyPlans, weeklyPlans, monthlyPlans)',
              enum: ['dailyPlans', 'weeklyPlans', 'monthlyPlans']
            },
            planId: {
              type: 'string',
              description: '계획 ID'
            }
          },
          required: ['collection', 'planId']
        }
      },
      {
        name: 'delete_plan',
        description: '계획을 삭제합니다',
        inputSchema: {
          type: 'object',
          properties: {
            collection: {
              type: 'string',
              description: '컬렉션 이름 (dailyPlans, weeklyPlans, monthlyPlans)',
              enum: ['dailyPlans', 'weeklyPlans', 'monthlyPlans']
            },
            planId: {
              type: 'string',
              description: '계획 ID'
            }
          },
          required: ['collection', 'planId']
        }
      }
    ],
  };
});

// 도구 실행 핸들러
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'add_daily_plan': {
        const { userId, date, title, subject = '', notes = '' } = args as any;
        const dateObj = new Date(date);

        const docRef = await db.collection('dailyPlans').add({
          userId,
          date: admin.firestore.Timestamp.fromDate(dateObj),
          title,
          subject,
          notes,
          isCompleted: false,
          startTime: null,
          endTime: null,
          actualStudyTime: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return {
          content: [
            {
              type: 'text',
              text: `✅ 일일 계획이 추가되었습니다!\nID: ${docRef.id}\n제목: ${title}\n날짜: ${date}`
            }
          ]
        };
      }

      case 'add_weekly_plan': {
        const { userId, date, title, subject = '', pageRanges = [], notes = '' } = args as any;
        const dateObj = new Date(date);

        const docRef = await db.collection('weeklyPlans').add({
          userId,
          date: admin.firestore.Timestamp.fromDate(dateObj),
          title,
          subject,
          subjectId: null,
          pageRanges: pageRanges || [],
          notes,
          isCompleted: false,
          parentMonthlyId: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return {
          content: [
            {
              type: 'text',
              text: `✅ 주간 계획이 추가되었습니다!\nID: ${docRef.id}\n제목: ${title}\n날짜: ${date}`
            }
          ]
        };
      }

      case 'add_monthly_goal': {
        const { userId, month, title, subject = '', endDate, priority = 2, notes = '' } = args as any;

        const data: any = {
          userId,
          month,
          title,
          subject,
          subjectId: null,
          pageRanges: [],
          startDate: null,
          endDate: endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) : null,
          subtasks: [],
          tag: '',
          priority,
          isCompleted: false,
          relatedWeeklyIds: [],
          notes,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        const docRef = await db.collection('monthlyPlans').add(data);

        return {
          content: [
            {
              type: 'text',
              text: `✅ 월간 목표가 추가되었습니다!\nID: ${docRef.id}\n제목: ${title}\n월: ${month}${endDate ? `\n마감일: ${endDate}` : ''}`
            }
          ]
        };
      }

      case 'get_daily_plans': {
        const { userId, date } = args as any;
        const dateObj = new Date(date);
        const startOfDay = new Date(dateObj.setHours(0, 0, 0, 0));
        const endOfDay = new Date(dateObj.setHours(23, 59, 59, 999));

        const snapshot = await db.collection('dailyPlans')
          .where('userId', '==', userId)
          .where('date', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
          .where('date', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
          .get();

        const plans = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        return {
          content: [
            {
              type: 'text',
              text: plans.length > 0
                ? `📅 ${date} 일일 계획:\n\n${plans.map((p: any, i) =>
                    `${i + 1}. ${p.isCompleted ? '✅' : '⬜'} ${p.title}\n   과목: ${p.subject || '없음'}\n   ID: ${p.id}`
                  ).join('\n\n')}`
                : `${date}에 등록된 일일 계획이 없습니다.`
            }
          ]
        };
      }

      case 'get_weekly_plans': {
        const { userId, startDate, endDate } = args as any;
        const start = admin.firestore.Timestamp.fromDate(new Date(startDate));
        const end = admin.firestore.Timestamp.fromDate(new Date(endDate));

        const snapshot = await db.collection('weeklyPlans')
          .where('userId', '==', userId)
          .where('date', '>=', start)
          .where('date', '<=', end)
          .get();

        const plans = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        return {
          content: [
            {
              type: 'text',
              text: plans.length > 0
                ? `📆 ${startDate} ~ ${endDate} 주간 계획:\n\n${plans.map((p: any, i) =>
                    `${i + 1}. ${p.isCompleted ? '✅' : '⬜'} ${p.title}\n   과목: ${p.subject || '없음'}\n   페이지: ${p.pageRanges?.join(', ') || '없음'}\n   ID: ${p.id}`
                  ).join('\n\n')}`
                : `해당 기간에 등록된 주간 계획이 없습니다.`
            }
          ]
        };
      }

      case 'get_monthly_goals': {
        const { userId, month } = args as any;

        const snapshot = await db.collection('monthlyPlans')
          .where('userId', '==', userId)
          .where('month', '==', month)
          .get();

        const goals = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        return {
          content: [
            {
              type: 'text',
              text: goals.length > 0
                ? `🎯 ${month} 월간 목표:\n\n${goals.map((g: any, i) => {
                    const priorityEmoji = g.priority === 1 ? '🔴' : g.priority === 2 ? '🟡' : '🟢';
                    return `${i + 1}. ${g.isCompleted ? '✅' : '⬜'} ${priorityEmoji} ${g.title}\n   과목: ${g.subject || '없음'}\n   ID: ${g.id}`;
                  }).join('\n\n')}`
                : `${month}에 등록된 월간 목표가 없습니다.`
            }
          ]
        };
      }

      case 'complete_plan': {
        const { collection, planId } = args as any;

        await db.collection(collection).doc(planId).update({
          isCompleted: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        return {
          content: [
            {
              type: 'text',
              text: `✅ 계획이 완료되었습니다! (ID: ${planId})`
            }
          ]
        };
      }

      case 'delete_plan': {
        const { collection, planId } = args as any;

        await db.collection(collection).doc(planId).delete();

        return {
          content: [
            {
              type: 'text',
              text: `🗑️ 계획이 삭제되었습니다! (ID: ${planId})`
            }
          ]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    return {
      content: [
        {
          type: 'text',
          text: `❌ 오류 발생: ${error.message}`
        }
      ],
      isError: true,
    };
  }
});

// 서버 시작
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Study Planner MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
