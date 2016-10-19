#include "textflag.h"

// func setRunArg(arg int64)
TEXT ·setRunArg(SB),$0-8
	PUSHQ	AX
	MOVQ	arg+0(FP), AX
	MOVQ	AX, M4
	POPQ	AX
	RET

// func getRunResult() int32
TEXT ·getRunResult(SB),$0-4
	PUSHQ	AX
	MOVL	M5, AX
	MOVL	AX, ret+0(FP)
	POPQ	AX
	RET

// func run(text []byte, initialMemorySize int, memoryAddr, growMemorySize uintptr, stack []byte, stackOffset, resumeResult, slaveFd int) (trap int, currentMemorySize int, stackPtr uintptr)
TEXT ·run(SB),$0-120
	PUSHQ	AX
	PUSHQ	CX
	PUSHQ	DX
	PUSHQ	BX
	PUSHQ	BP
	PUSHQ	SI
	PUSHQ	DI
	PUSHQ	R8
	PUSHQ	R9
	PUSHQ	R10
	PUSHQ	R11
	PUSHQ	R12
	PUSHQ	R13
	PUSHQ	R14
	PUSHQ	R15

	MOVQ	text+0(FP), R12
	MOVQ	initialMemorySize+24(FP), R15
	MOVQ	memoryAddr+32(FP), R14	// memory ptr
	MOVQ	growMemorySize+40(FP), BX
	ADDQ	R14, R15		// current memory limit
	ADDQ	R14, BX			// memory growth limit
	MOVQ	stack+48(FP), R13	// stack limit
	MOVQ	stackOffset+72(FP), CX
	ADDQ	R13, CX			// stack ptr
	MOVQ	resumeResult+80(FP), AX	// resume result (0 = don't resume)
	MOVQ	slaveFd+88(FP), M6	// slave fd
	CALL	run<>(SB)
	MOVQ	DI, trap+96(FP)
	SUBQ	R14, R15
	MOVQ	R15, currentMemorySize+104(FP)
	MOVQ	BX, stackPtr+112(FP)

	POPQ	R15
	POPQ	R14
	POPQ	R13
	POPQ	R12
	POPQ	R11
	POPQ	R10
	POPQ	R9
	POPQ	R8
	POPQ	DI
	POPQ	SI
	POPQ	BP
	POPQ	BX
	POPQ	DX
	POPQ	CX
	POPQ	AX
	RET

TEXT run<>(SB),NOSPLIT,$0
	MOVQ	SP, M7		// save original stack
	MOVQ	CX, SP		// stack ptr
	LEAQ	trap<>(SB), R9
	MOVQ	R9, M0		// trap handler
	MOVQ	BX, M1		// memory growth limit
	MOVQ	R12, DI
	ADDQ	$16, DI		// skip trap at start of text
	JMP	DI
	// exits via trap handler

TEXT trap<>(SB),NOSPLIT,$0
	CMPQ	DI, $1		// MissingFunction
	JE	pause

	MOVQ	SP, BX		// stack ptr
	MOVQ	M7, SP		// restore original stack
	RET

pause:
	MOVL	$1, AX		// sys_write
	MOVQ	M6, DI 		// fd
	LEAQ	-8(SP), SI	// buf
	MOVQ	$-2, (SI)	// buf content
	MOVL	$8, DX		// bufsize
	SYSCALL
	SUBQ	DX, AX
	JNE	fail

	XORL	AX, AX		// sys_read
	MOVL	$1, DX		// bufsize
	SYSCALL
	SUBQ	DX, AX
	JNE	fail

	SUBQ	$5, (SP)	// move return address before the call that got us here
	RET

fail:
	MOVQ	$3003, DI
	JMP	trap<>(SB)

// func importSpectestPrint() uint64
TEXT ·importSpectestPrint(SB),$0-8
	PUSHQ	AX
	LEAQ	spectestPrint<>(SB), AX
	MOVQ	AX, ret+0(FP)
	POPQ	AX
	RET

TEXT spectestPrint<>(SB),NOSPLIT,$0
	MOVL	$1, AX		// sys_write
	MOVQ	M6, DI 		// fd
	INCL	DX		// 1 + argcount
	SHLL	$3, DX		// (1 + argcount) * wordsize = bufsize
	MOVQ	SP, SI		// buf end
	SUBQ	DX, SI		// buf
	MOVQ	BX, (SI)	// write sigindex before args
	SYSCALL
	SUBQ	DX, AX
	JNE	fail
	RET

fail:
	MOVQ	$3001, DI
	JMP	trap<>(SB)

// func importGetArg() uint64
TEXT ·importGetArg(SB),$0-8
	PUSHQ	AX
	LEAQ	getArg<>(SB), AX
	MOVQ	AX, ret+0(FP)
	POPQ	AX
	RET

TEXT getArg<>(SB),NOSPLIT,$0
	MOVQ	M4, AX
	RET

// func importSetResult() uint64
TEXT ·importSetResult(SB),$0-8
	PUSHQ	AX
	LEAQ	setResult<>(SB), AX
	MOVQ	AX, ret+0(FP)
	POPQ	AX
	RET

TEXT setResult<>(SB),NOSPLIT,$0
	MOVL	CX, M5
	RET

// func importSnapshot() uint64
TEXT ·importSnapshot(SB),$0-8
	PUSHQ	AX
	LEAQ	snapshot<>(SB), AX
	MOVQ	AX, ret+0(FP)
	POPQ	AX
	RET

TEXT snapshot<>(SB),NOSPLIT,$0
	MOVL	$1, AX		// sys_write
	MOVQ	M6, DI 		// fd
	LEAQ	-8(SP), SI	// buf
	MOVQ	$-1, (SI)	// buf contents
	MOVL	$8, DX		// bufsize
	SYSCALL
	SUBQ	DX, AX
	JNE	fail

	MOVL	$1, AX		// sys_write
	MOVQ	R15, (SI)	// buf contents
	SYSCALL
	SUBQ	DX, AX
	JNE	fail

	MOVL	$1, AX		// sys_write
	MOVQ	SP, (SI)	// buf contents
	SYSCALL
	SUBQ	DX, AX
	JNE	fail

	XORL	AX, AX		// sys_read
	SYSCALL
	SUBQ	DX, AX
	JNE	fail
	MOVQ	(SI), AX	// snapshot id
	RET

fail:
	MOVQ	$3002, DI
	JMP	trap<>(SB)
