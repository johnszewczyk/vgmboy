#include "MdLogicTest.h"
#include "MemStream.h"

#define CONSTANT_1 (0x55555555)
#define CONSTANT_2 (0xCCCCCCCC)
#define CONSTANT_3 (0xF0F0F0F0)

void CMdLogicTest::Run()
{
	memset(&m_context, 0, sizeof(m_context));

	for(unsigned int i = 0; i < 4; i++)
	{
		m_context.op1[i] = CONSTANT_1;
		m_context.op2[i] = CONSTANT_2;
		m_context.op3[i] = CONSTANT_3;
	}

	m_function(&m_context);

	for(unsigned int i = 0; i < 4; i++)
	{
		TEST_VERIFY(m_context.resultOr[i] == (CONSTANT_1 | CONSTANT_2));
		TEST_VERIFY(m_context.resultXor[i] == (CONSTANT_1 ^ CONSTANT_2));
		TEST_VERIFY(m_context.resultAnd[i] == (CONSTANT_1 & CONSTANT_2));
		TEST_VERIFY(m_context.resultNot[i] == ~CONSTANT_1);
		TEST_VERIFY(m_context.resultSelect[i] == ((CONSTANT_1 & CONSTANT_3) | (CONSTANT_2 & ~CONSTANT_3)));
	}
}

void CMdLogicTest::Compile(Jitter::CJitter& jitter)
{
	Framework::CMemStream codeStream;
	jitter.SetStream(&codeStream);

	jitter.Begin();
	{
		jitter.MD_PushRel(offsetof(CONTEXT, op1));
		jitter.MD_PushRel(offsetof(CONTEXT, op2));
		jitter.MD_Or();
		jitter.MD_PullRel(offsetof(CONTEXT, resultOr));

		jitter.MD_PushRel(offsetof(CONTEXT, op1));
		jitter.MD_PushRel(offsetof(CONTEXT, op2));
		jitter.MD_Xor();
		jitter.MD_PullRel(offsetof(CONTEXT, resultXor));

		jitter.MD_PushRel(offsetof(CONTEXT, op1));
		jitter.MD_PushRel(offsetof(CONTEXT, op2));
		jitter.MD_And();
		jitter.MD_PullRel(offsetof(CONTEXT, resultAnd));

		jitter.MD_PushRel(offsetof(CONTEXT, op1));
		jitter.MD_Not();
		jitter.MD_PullRel(offsetof(CONTEXT, resultNot));

		jitter.MD_PushRel(offsetof(CONTEXT, op1));
		jitter.MD_PushRel(offsetof(CONTEXT, op2));
		jitter.MD_PushRel(offsetof(CONTEXT, op3));
		jitter.MD_BitSelect();
		jitter.MD_PullRel(offsetof(CONTEXT, resultSelect));
	}
	jitter.End();

	m_function = FunctionType(codeStream.GetBuffer(), codeStream.GetSize());
}
