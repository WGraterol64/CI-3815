.data

    input: .word 0
    message: .ascii "El computador esta bloqueado.\n"
    exit_message: .ascii "\nEl computador ha sido desbloqueado.\n"
       
.text
 	
 	main:
		li $t0, 0xffff0008
		li $t1, 2
		sw $t1, -8($t0)
	print:
		la $t1, message
		addi $t2, $t1, 30
	loop:
		
		lw $t4, input
		bgt $t4, $0, unlocked
		
		lw $t3, 0($t0)
		andi $t3, $t3, 1
		beqz $t3, loop
		lb $a0, 0($t1)
		sb $a0, 4($t0)		
		
		addi $t1, $t1, 1
		beq $t1,$t2,print		
		b loop
		
	unlocked:
		la $t1, exit_message
		addi $t2, $t1, 37
	
	_loop:
		lw $t3, 0($t0)
		andi $t3, $t3, 1
		beqz $t3, _loop
		lb $a0, 0($t1)
		sb $a0, 4($t0)		
		addi $t1, $t1, 1
		bne $t1,$t2,_loop
		
	
		
		
		

# Manejador de excepciones
.kdata
__m1_:	.asciiz "  Exception "
__m2_:	.asciiz " occurred and ignored\n"
__e0_:	.asciiz "  [Interrupt] "
__e1_:	.asciiz	"  [TLB]"
__e2_:	.asciiz	"  [TLB]"
__e3_:	.asciiz	"  [TLB]"
__e4_:	.asciiz	"  [Address error in inst/data fetch] "
__e5_:	.asciiz	"  [Address error in store] "
__e6_:	.asciiz	"  [Bad instruction address] "
__e7_:	.asciiz	"  [Bad data address] "
__e8_:	.asciiz	"  [Error in syscall] "
__e9_:	.asciiz	"  [Breakpoint] "
__e10_:	.asciiz	"  [Reserved instruction] "
__e11_:	.asciiz	""
__e12_:	.asciiz	"  [Arithmetic overflow] "
__e13_:	.asciiz	"  [Trap] "
__e14_:	.asciiz	""
__e15_:	.asciiz	"  [Floating point] "
__e16_:	.asciiz	""
__e17_:	.asciiz	""
__e18_:	.asciiz	"  [Coproc 2]"
__e19_:	.asciiz	""
__e20_:	.asciiz	""
__e21_:	.asciiz	""
__e22_:	.asciiz	"  [MDMX]"
__e23_:	.asciiz	"  [Watch]"
__e24_:	.asciiz	"  [Machine check]"
__e25_:	.asciiz	""
__e26_:	.asciiz	""
__e27_:	.asciiz	""
__e28_:	.asciiz	""
__e29_:	.asciiz	""
__e30_:	.asciiz	"  [Cache]"
__e31_:	.asciiz	""
__excp:	.word __e0_, __e1_, __e2_, __e3_, __e4_, __e5_, __e6_, __e7_, __e8_, __e9_
	.word __e10_, __e11_, __e12_, __e13_, __e14_, __e15_, __e16_, __e17_, __e18_,
	.word __e19_, __e20_, __e21_, __e22_, __e23_, __e24_, __e25_, __e26_, __e27_,
	.word __e28_, __e29_, __e30_, __e31_
s1:	.word 0
s2:	.word 0

#####################################################
# This is the exception handler code that the processor runs when
# an exception occurs. It only prints some information about the
# exception, but can serve as a model of how to write a handler.
#
# Because we are running in the kernel, we can use $k0/$k1 without
# saving their old values.

# This is the exception vector address for MIPS32:
.ktext 0x80000180

#####################################################
# Save $at, $v0, and $a0
#

	move $k1 $at            # Save $at

	sw $v0 s1               # Not re-entrant and we can't trust $sp
	sw $a0 s2               # But we need to use these registers


#####################################################
# Print information about exception
#
	li $v0 4                # syscall 4 (print_str)
	la $a0 __m1_
	syscall

	li $v0 1                # syscall 1 (print_int)
	mfc0 $k0 $13            # Get Cause register
	srl $a0 $k0 2           # Extract ExcCode Field
	andi $a0 $a0 0xf
	syscall

	li $v0 4                # syscall 4 (print_str)
	andi $a0 $k0 0x3c
	lw $a0 __excp($a0)      # $a0 has the index into
	                        # the __excp array (exception
	                        # number * 4)
	nop
	syscall

#####################################################
# Bad PC exception requires special checks
#
	bne $k0 0x18 ok_pc
	nop

	mfc0 $a0 $14            # EPC
	andi $a0 $a0 0x3        # Is EPC word-aligned?
	beq $a0 0 ok_pc
	nop

	li $v0 10               # Exit on really bad PC
	syscall

#####################################################
#  PC is alright to continue
#
ok_pc:

	li $v0 4                # syscall 4 (print_str)
	la $a0 __m2_            # "occurred and ignored" message
	syscall

	srl $a0 $k0 2           # Extract ExcCode Field
	andi $a0 $a0 0xf
	bne $a0 0 key_input           # 0 means exception was an interrupt
	nop

#####################################################
# Interrupt-specific code goes here!
# Don't skip instruction at EPC since it has not executed.
#  
key_input:
      srl $a0 $k0 2
      andi $a0 $a0 0x3f
      bne $a0 $zero ret
      lbu $a0, 0xffff0004
      bne $a0 0x20 ret
      li $a0 1
      sw $a0 input

#####################################################
# Return from (non-interrupt) exception. Skip offending
# instruction at EPC to avoid infinite loop.
#
ret:

	mfc0 $k0 $14            # Get EPC register value
	addiu $k0 $k0 4         # Skip faulting instruction by skipping
	                        # forward by one instruction
                                # (Need to handle delayed branch case here)
	mtc0 $k0 $14            # Reset the EPC register

regresar:
#####################################################
# Restore registers and reset procesor state
#
	lw $v0 s1               # Restore $v0 and $a0
	lw $a0 s2


	move $at $k1            # Restore $at


	mtc0 $0 $13             # Clear Cause register

	mfc0 $k0 $12            # Set Status register
	ori  $k0 0x1            # Interrupts enabled
	mtc0 $k0 $12


#####################################################
# Return from exception on MIPS32
#
	eret

# End of exception handling
#####################################################
	