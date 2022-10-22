org 0x7c00
bits 16


%define ENDL 0x0D, 0x0A


;
;	FAT12 header
;
jmp short start
nop

bdb_oem:					db 'MSWIN4.1'			; 8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:			dw 2880					; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h					; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

;	extended boot record
ebr_drive_number:			db 0
							db 0
ebr_sgignature:				db 29h
ebr_volume_id:				db 12h, 34h, 56h, 78h
ebr_volume_label:			db 'ATOMIC OS  '
ebr_system_id:				db 'FAT 12    '



start:
	jmp main


;
; prints a string to the screen
; params:
; - ds:si points to string
;
puts:
	push si
	push ax


.loop:
	lodsb 		; loads next character in al
	or al, al	; verify if next character is null?
	jz .done
	

	mov ah, 0x0e
	mov bh, 0
	int 0x10

	jmp .loop

.done:
	pop ax
	pop si
	ret



main:

	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setting up stacks
	mov ss, ax
	mov sp, 0x7c00

	; read some data form disk
	mov [ebr_drive_number], dl

	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read


	;print msg here
	mov si, msg_hello
	call puts

	cli
	hlt

;
; Errorr handlers
;

floppy_error:
	mov si, message_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h
	jmp 0FFFFh:0

.halt:
	cli
	hlt


;
; Disk routines
;


; Converts an LBA address to a CHS address
; parameters:
; - ax: LBA address
;Returns:
; -cx [bits 0-5]: sector number
; - cx [bits 6 - 15]: cylinder
; - dh: head

lba_to_chs:
	
	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack
	
	inc dx								; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl							; dh = head
	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in CL


	pop ax
	mov dl, al
	pop ax
	ret



;Reads sectors from a disk:
; Params:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- ex:bx: memory address where to store read data
disk_read:

	push ax
	push bx
	push cx
	push dx
	push di	

	push cx				; temporarily save cl
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3

.retry:
	pusha
	stc
	int 13h
	jnc .done

	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret


msg_hello:				db 'Hello World!', ENDL,  0
message_read_failed:	db 'AOS-CR: Read from disk failed!!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
