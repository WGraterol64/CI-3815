###################################
# MVML-grupoA                     #
# Fecha: 30/11/2018               #
# Proyecto CI-3815 Fase III       #
# Autores:                        #
#     Jesus De Aguiar   15-10360  #
#     Wilfredo Graterol 15-10639  #
###################################

# Macros para imprimir caracteres y numeros
.macro print_str(%x)
la $a0, %x
li $v0, 4
syscall
.end_macro

.macro print_dec_int(%x)
move $a0, %x
li $v0, 1
syscall
.end_macro

.macro print_hex_int(%x)
move $a0, %x
li $v0, 34
syscall
.end_macro

.macro print_newline
li $a0, 0xa
li $v0, 11
syscall
.end_macro


.data

     # Mensaje inicial para e usuario
    prompt: .asciiz "Introduzca el nombre del archivo: "

    # Mensaje para la salida
    register_exit: .asciiz "Los contenidos de los registros son los siguientes: \n"

    # Mensaje de salida para cada registro
    register_msg: .asciiz "Registro $"

    # Cadema para imprimir el pc
    pc_msg: .asciiz "PC\n"

    # Mensaje para solicitar numero de palabras a imprimir
    word_prompt: .asciiz "Introduzca el numero de palabras que desea imprimir: "

    # Mensaje en caso de que el usuario desee imprimir mas palabras de las que hay
    word_overflow: .asciiz "Solo hay 500 palabras, se procedera a imprimir todas las que hay: \n"

    # Mensaje antes de imprimir las palabras
    word_ok: .asciiz "Los contenidos de las palabras son los siguientes: \n"

    # Mensaje antes de imprimir cada palabra
    word_msg: .asciiz "Palabra "

    # Mensaje de error en caso de que un branch salga del segmento de texto de la maquina virtual
    branch_error_msg: .asciiz "Error. Branch fuera del area de datos"

    # Mensaje de error si se intenta acceder a un espacio de memoria que este fuera del rango de la maquina virtual
    data_error_msg: .asciiz "Error intentando acceder a memoria fuera del area permitida o direccion no alineada."

    # Mensaje en caso de no poder conseguir el archivo
    file_error_msg: .asciiz "No se pudo encontrar el archivo"

    # Mensaje en caso de operaciones no definidas
    not_defined: .asciiz "Operacion no definida aun"

    # Lugar donde se guardara el nombre del archivo a leer
    filename: .space 20

    # Espacio donde estaran las lineas que se iran leyendo
    buffer: .space 8

    # Arreglo de los tipos de cada instruccion
    type: .ascii "R000RII0I000II0000000000R0000000R0RI0R00R00I"
    .align 2

    # Vector de direccion de las funciones en el segmento de texto
    operations: .word _halt, ns, ns, ns, _sllv, _bne, _beq, ns, _addi, ns, ns, ns, _andi, _ori, ns, ns, ns, ns, ns, ns, ns, ns, ns, ns, _mult, ns, ns, ns, ns, ns, ns, ns, _add, ns, _sub, _lw, ns, _or, ns, ns, _and, ns, ns, _sw

    .align 2

    # Espacio donde se guardaran las instrucciones traducidas
    instructions: .space 400

    # Registros de MVML
    registers: .space 132

    # Espacio de datos de MVML
    _data: .space 2000

.text
#####################################################################################################################################################
#### Inicio del programa

    # En esta parte se realizan las llamadas a la lectura y decodificacion del archivo que contiene las instrucciones
    
    # Registros utilizados en esta parte:
    
    # $v0, $a0, $a1: Son utilizadas para las llamadas al sistema, en este caso serian de impresion y
    #                para pedir el nombre del archivo al usuario
    # $s0: Utilizado para direccionar y guardar el PC de la maquina virtual en memoria

    main:

        print_str(prompt)          # Imprimir mensaje al usuario para pedir nombre del archivo

        li $v0, 8
        la $a0, filename
        li $a1, 20
        syscall                    # Recibe del usuario el nombre del archivo
        
        jal debug                  # Depuramos el nombre del archivo

        li   $v0, 13
        la   $a0, filename
        li   $a1, 0
        li   $a2, 0
        syscall                    # Abrir el archivo 

        move $a0, $v0              # Guardamos el descriptor como parametro para load
        blt $a0, $zero, file_error # Si el descriptor es negativo, ocurrio un error

        jal load                   # Cargamos las instrucciones a memoria

        li $v0, 16
	syscall                    # Cerramos el archivo abierto

	jal decode_and_run         # Empezamos la decodificacion y ejecutamos las instrucciones

	la $s0, registers          # Guardamos el pc virtual en memoria
	addi $s0, $s0, 128
	sw $v0, 0($s0)
	b register_print
	
    file_error:
   	print_str(file_error_msg)  # Imprimimos mensaje de error
        j exit                     # Salimos del programa

#####################################################################################################################################################
#### Realizamos las impresiones, empezando por los registros y luego con las palabras de memoria
	
    # La planificacion de registros para esta parte es la siguiente:
        
    # $t0: Guarda la direccion de la tabla de registros
    # $t1: Con ella recorremos la tabla de registros
    # $t2: Para comparar y poder salir del loop de impresion de registros
    # $s0: Guarda la direccion de la memoria de la maquina virtual
    # $s1: Con ella recorremos las palabras en la memoria de la maquina virtual
    # $s2: Para comparar y poder salir del loop de impresion de las palabras en memoria
    # $a1, $v0: Las utilizamos para imprimir y recibir datos con los syscall

    register_print:

        print_str(register_exit)   # Imprimimos mensajeal usuario para empezar a imprimir los registros
        la $t0, registers          # Cargamos los datos necesarios para direccionar
        li $t1, 0
        li $t2, 128

    register_loop:

        beq $t1, $t2, print_pc     # Si el registro es el pc (el ultimo registro) hacemos una impresion especial
        print_str(register_msg)    # Imprimir identificacion de registro
        srl $a1, $t1, 2
        print_dec_int($a1)
   	print_newline
   	add $a1, $t0, $t1
   	lw $a1, ($a1)
   	print_dec_int($a1)         # Imprimir el contenido del registro en decimal
   	print_newline
   	print_hex_int($a1)         # Imprimir el contenido del registro en hexadecimal
   	print_newline
   	addi $t1, $t1, 4           # Seguir con siguiente registro
   	b register_loop

   print_pc:

   	print_str(pc_msg)          # Imprimir el identificador del pc
   	la $s0, registers
   	addi $s0, $s0, 128
   	lw $a1, 0($s0)
   	print_dec_int($a1)         # Imprimir el contenido del pc en decimal
   	print_newline
   	print_hex_int($a1)	   # Imprimir el contenido del pc en hexadecimal
   	print_newline
   	print_newline

    print_words:
        print_str(word_prompt)     # Imprimimos mensaje al usuario para solicitar el numero de palabras a imprimir
        li $v0, 5
        syscall                    # En $v0 queda el numero de palabras que desea ver el usuario

        li $s0, 500
        move $s2, $v0
        bge $s0, $s2, ok           # Verificamos si se piden imprimir mas palabras de las que hay
        li $s2, 500                # En ese caso se imprime que es imposible y se imprimen las 500 que hay
        print_str(word_overflow)

    ok:
        print_str(word_ok)         # Imprimimos mensaje de inicializacion de la impresion
        la $s0, _data              # Inizializamos los registros que utilizaremos para direccionar
        li $s1, 0
        sll $s2, $s2, 2

    word_loop:
        beq $s1, $s2, exit         # Mientras que no hayamos llegado al limite de palabras a imprimir, seguimos
        print_str(word_msg)        # Imprimir el identificador de la palabra
        srl $a1, $s1, 2
        print_dec_int($a1)
        print_newline
   	add $a0, $s0, $s1          # Direccionamos
   	lw $a1, ($a0)
   	print_dec_int($a1)         # Imprimir el contenido en decimal
   	print_newline
   	print_hex_int($a1)         # Imprimir el contenido en hexadecimal
	print_newline
   	addi $s1, $s1, 4           # Seguir con la siguiente palabra
   	b word_loop

    exit:
        li $v0, 10                 # Terminar el programa
   	syscall

    return:
     	jr $ra

#####################################################################################################################################################
#### Funcion para debugear el nombre del archivo 

    # Depuracion del nombre del archivo con un ciclo iterando byte a byte
    # desde el inicio de "filename" hasta conseguir 0xa y cambiarlo por 0
    # si se consigue, de lo contrario se procede a abrir el archivo
	
    # La planificacion de registros para esta parte es la siguiente:
        
    # $t0: Byte 0xa que queremos eliminar, lo usaremos para comparaciones
    # $t1: Byte que estamos leyendo al momento
    # $t2: Direccion del byte que se esta leyendo
    # $t3: Direccion del final del espacio reservado para el nombre del documento   
    
    debug:

      	li $t0,0xa                 # Cargamos los valores iniciales
      	la $t2,filename
      	addi $t3, $t2, 20
      	lb $t1,0($t2)

     loop_debug:

     	beq $t2,$t3,return         # Si llegamos al final del espacio,volvemos al main
     	beq $t0,$t1,fix            # Si $t1 es 0xa, arreglamos el byte
     	addi $t2,$t2,1             # Cambiamos las direcciones para procesar el siguiente byte
     	lb $t1,0($t2)
     	b loop_debug               # loop

     fix:

     	li $t0,0                   # Guardamos el caracter nulo en la direccion
     	sb $t0,0($t2)              # del caracter que estamos procesando
     	jr $ra

#####################################################################################################################################################
#### Cargar las instrucciones a memoria
        
    # En esta parte iremos leyendo el archivo linea por linea,
    # traduciendolo y cargando en memoria su cotenido
        
    # La planificacion de registros para esta parte es la siguiente:
        
    # $v0: Los codigos necesarios para syscall y el resultado de el mismo
    # $a0, $a1, $a2: Data necesaria para los syscall
    # $s0: Descriptor del archivo
    # $t0: Proxima direccion en la que se guardara el byte traducido
    # $t1: Direccion que se esta leyendo
    # $t2: Direccion del final del buffer, lo usamos para saber cuando 
    #      terminamos con la linea actual
    # $t3: Byte que se esta procesando actualmente, byte que se almacenara
    # $t4: Ultimo byte que se leyo, el cual debe despues combinarse con el 
    #      que este en $t3 mediante operaciones logicas
    # $t5: Contador que oscila entre 0 y 1 el cual indica cuando debemos 
    #      guardar un byte traducido
    # $t6: Direccion del final de la palabra en la cual se esta guardando 
    #      la instruccion, la utilizamos para comparar y cambiar de palabra
       
   load:
        la $t0, instructions       # Inicializacion de los registros
        addi $t6, $t0, -1
        addi $t0, $t0, 3
        la $t2, buffer
        addi $t2, $t2, 8
        li $t5, 0                  # En $a0 se encuentra el descriptor
        la   $a1, buffer           # Input Buffer
        li   $a2, 8                # Numero de caracteres a leer

  read_loop:
        li   $v0, 14               # Codigo de syscall para leer archivos
        syscall
        beq $v0,$zero, return      # si ya terminamos de leer, volvemos al main
        beq $v0, 0xffffffff, exit  # Si hubo error, salir del programa
        la $t1, buffer             # En $t1 guardamos la direccion que estamos leyendo

    save:
        beq $t1, $t2, read_loop    # Si ya terminamos con la linea actual, leer otra
        lb $t3, 0($t1)             # Cargar en $t3 el caracter a procesar
        bgt  $t3, 47, translate    # Si es un numero o letra, traducir
        addi $t1, $t1, 1           # Si no, pasar al siguiente caracter
        b save                     # Volver al loop

   translate:
        bgt $t3, 96, letter        # Si es una letra, saltar
        andi $t3, $t3, 0xf         # Si solo es un numero, extraer los ultimos bits
        b continue                 # Seguir procesando el numero

   letter:
        andi $t3, $t3, 0xf         # Extraer los ultimos bits
        addi $t3, $t3, 9           # Cargar la letra correspondiente

   continue:
        beq  $t5, 1, join          # Si es el segundo caracter que procesamos
        addi $t5, $t5, 1           # lo unimos con el anterior
        move $t4, $t3              # Si no, lo almacenamos y cambiamos a $t5
        addi $t1, $t1, 1           # Pasamos al siguiente caracter
        b save                     # loop

   join:
       sll $t4, $t4, 4             # Correr 4 bits lo extraido del caracter
       or $t3, $t3, $t4            # Unir logicamente con el anterior
       sb $t3, 0($t0)              # Guardarlo en memoria
       li $t5, 0                   # Cambiar el valor de $t0
       addi $t1, $t1, 1            # Pasar al siguiente caracter
       addi $t0, $t0, -1           # Pasar a la siguiente direccion de memoria en la palabra
       beq $t0, $t6, adjust        # Si llegamos al final de la palabra, ajustamos la direccion
       b save                      # loop

   adjust:
       addi $t0, $t0, 8            # Pasar a la siguiente palabra
       addi $t6, $t0, -4           # Ajustar el marcador del final de la palabra
       b save                      # loop

#####################################################################################################################################################
#### Decodificacion
        
    # En esta parte decodificamos cada una de las instrucciones dadas en el archivo 
    # y las ejecutamos dentro de nuestra maquina virtual.
       
    # La planificacion de registros para esta parte es la siguiente::
        
    # $a0, $a1, $a2: Parametros que se les pasaran a las funciones, 
    #                tendran direcciones o valores segun sea el casi
    # $t0: PC de la maquina virtual
    # $t1: Codigo de operacion de la instruccion, registros y offsets a imprimir
    # $t2: Cargar el formato de instruccion y para direccionar
    # $t5: El byte 0x30, que representara formato de operaciones no definidas aun
    # $t6: Codigo de la operacion actual
    # $t7: El byte 0x52, que representara formato de operaciones tipo R

   decode_and_run:

	addi $sp, $sp, -4          # Guardamos el $ra en la pila para poder retornar
   	sw $ra, 4($sp)
   	la $t0, instructions       # inicializacion de $t0 antes del loop
   	la $t5, 0x30
   	li $t7, 0x52

   loop_decode:

   	lw $t1, 0($t0)             # Cargamos una instruccion
   	move $t6, $t1              # Guardamos el codigo de la instruccion en $t6
   	andi $t1, 0xfc000000       # Extraemos el codigo de operacion con un and y un shift
   	srl $t1, $t1, 26           # El codigo de operacion queda almacenado en $t1

   	la $t2, type               # Utilizaremos direccionamiento directo
   	add $t2, $t2, $t1          # Sumamos a la direccion type, el codigo de operacion
   	lb $t2, 0($t2)             # Guardamos el tipo de la operacion

   	beq $t5, $t2, ns           # Si el tipo de la operacion es 0, la op. no esta definida

   	beq $t2, $t7, type_R       # Si el tipo es R, saltar

  type_I:

   	andi $a0,$t6,0x001f0000    # Exraemos el registro destino
   	srl $a0, $a0, 14           # Calculamos 4*$rt

   	andi $a1, $t6, 0x03e00000  # Extraemos el registro fuente
   	srl $a1, $a1, 19           # Calculamos 4*$rs

   	andi $a2,$t6,0x0000ffff    # Extraer el offset del codigo de operacion
   	andi $t2,$t6,0x00008000
   	beqz $t2, direct           # Si el numero es positivo, ya tiene el signo extendido por defecto
   	ori $a2, 0xffff0000        # Extendemos el signo si es negativo

  direct:
        la $t2, registers          # Guardamos como argumentos la direccion de cada registro de la maquina virtual
        add $a0, $a0, $t2
        add $a1, $a1, $t2
   	b run_op                   # Saltamos a la rutina para ejecutar la instruccion

  type_R:

        beqz $t1, run_op           # Si la operacion es "halt", la ejecutamos

   	andi $a0, $t6, 0x0000f800  # Exraemos el registro destino
   	srl $a0, $a0, 9            # y lo multiplicmos por 4  

   	andi $a1, $t6, 0x03e00000  # Exraemos el registro fuente 1
   	srl $a1, $a1, 19           # y lo multiplicamos por 2

   	andi $a2, $t6, 0x001f0000  # Exraemos el registro fuente 2
   	srl $a2, $a2, 14           # y lo multiplicamos por 4

   	la $t2, registers          # Guardamos como argumentos la direccion de cada registro de la maquina virtual
        add $a0, $a0, $t2
        add $a1, $a1, $t2
        add $a2, $a2, $t2

   run_op:
	sll $t1, $t1, 2            # Multiplicamos por 4 el co-op para poder direccionar
	la $t2, operations
   	add $t2, $t1, $t2
   	lw $t2, 0($t2)             # Guardamos en $t2 la direccion el el segmento de texto de la funcion
   	addi $t0, $t0, 4           # Aumentar el pc de la maquina virtual

   	jalr $t2                   # Ejecutamos la instruccion
   	b loop_decode              # Seguimos con la siguiente instruccion

#####################################################################################################################################################
#### Instrucciones de MVML

    # La planificacion de regitros para cada funcion es:
    #    Si la operacion es tipo I, sus argumentos son:
    #    
    #    $a0: El registro destino ($rt)
    #    $a1: El registro fuente ($rs)
    #    $a2: El offset con la extension del signo
    #
    #    Si la operacion es tipo R, sus argumentos son:
    #
    #    $a0: El registro destino ($rd)
    #    $a1: El registro fuente 1 ($rs)
    #    $a2: El registro fuente 2 ($rt)
    #
    #    Ademas, tenemos en general que:
    #    
    #    $t2: Se utiliza para guardar los resultados de las operaciones y escribirlas en memoria
    #    $t3: Se utiliza para comparaciones de casos bordes
    #    $t0: Es el pc de la maquina virtual el cual puede ser modificado por un branch
    
   _add:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       add $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _addi:
       lw $a1, 0($a1)
       add $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _and:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       and $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _andi:
       lw $a1, 0($a1)
       andi $a2, $a2, 0x0000ffff    # Extendemos con 0 a la izquierda el offset
       and $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _mult:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       mul $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _or:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       or $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _ori:
       lw $a1, 0($a1)
       andi $a2, $a2, 0x0000ffff    # Extendemos con 0 a la izquierda el offset
       or $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _sllv:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       sllv  $t2, $a2, $a1
       sw $t2, 0($a0)
       jr $ra

   _sub:
       lw $a1, 0($a1)
       lw $a2, 0($a2)
       sub $t2, $a1, $a2
       sw $t2, 0($a0)
       jr $ra

   _lw:

        lw $a1, 0($a1)
	add $a1, $a1, $a2
	la $t2, _data
	add $a1, $a1, $t2
	addi $t3, $t2, 2000
	bge $a1, $t3, data_error    # Revisamos si la direccion es valido
	ble $a1, $t2, data_error    # Si no lo es, lanzamos un error
	andi $t3, $a1, 0x2
	bgt $t3, $0, data_error
	andi $t3, $a0, 0x2
	lw $t2, 0($a1)
	sw $t2, 0($a0)
	jr $ra

   _sw:

        lw $a1, 0($a1)
	add $a1, $a1, $a2
	la $t2, _data
	add $a1, $a1, $t2
	addi $t3, $t2, 2000
	bge $a1, $t3, data_error    # Revisamos si la direccion es valido
	ble $a1, $t2, data_error    # Si no lo es, lanzamos un error
	andi $t3, $a1, 0x2
	bgt $t3, $0, data_error
	lw $a0, ($a0)
	sw $a0, 0($a1)
	jr $ra

   data_error:
	print_str(data_error_msg)   # Error por acceso de memoria invalido
	print_newline
	j exit                      # Salir del programa

   _bne:
   	lw $a0, 0($a0)
   	lw $a1, 0($a1)
	beq $a0, $a1, return
	sll $a2, $a2, 2
	add $t0, $t0, $a2
	la $t2, instructions
	addi $t3, $t2, 400
	bge $t0, $t3, branch_error  # Revisamos si la instruccion es alcanzable
	ble $t0, $t2, branch_error  # Si no lo es, lanzamos un error
	jr $ra

   _beq:
   	lw $a0, 0($a0)
   	lw $a1, 0($a1)
	bne $a0, $a1, return
	sll $a2,$a2, 2
	add $t0, $t0, $a2
	la $t2, instructions
	addi $t3, $t2, 400
	bge $t0, $t3, branch_error  # Revisamos si nstruccion es alcanzable
	ble $t0, $t2, branch_error  # Si no lo es, lanzamos un error
	jr $ra

   branch_error:
	print_str(branch_error_msg) # Error por salirse del segmento de texto de la maquina virtual
	print_newline
	j exit                      # Salir del programa

   _halt:
   	move $v0, $t0
   	addi $sp, $sp, 4
   	lw $ra, 0($sp)
   	jr $ra   	            # Retornaremos al main

   ns:
       print_str(not_defined)       # Error por introducir una operacion no implementada aun
       print_newline
       j exit                       # Salir del programa

#####################################################################################################################################################
