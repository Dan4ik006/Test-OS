use16
org 0x4000

setup:
  ; 1. Установка режима VESA с LFB (800x600x32)
  mov ax, 0x4F02
  mov bx, 0x4144        ; LFB + 800x600x32
  int 0x10
  cmp ax, 0x004F
  jne .vesa_error

  ; 2. Получаем информацию о том же режиме
  mov ax, 0x4F01
  mov cx, 0x0144        
  mov di, vbe_info_block
  int 0x10
  cmp ax, 0x004F
  jne .vesa_error

  ; 3. Заполняем структуру screen_info
  mov eax, [vbe_info_block + 0x28]  ; PhysBasePtr
  mov [screen_info], eax
  mov ax, [vbe_info_block + 0x12]   ; XResolution
  mov [screen_info + 4], ax
  mov ax, [vbe_info_block + 0x14]    ; YResolution (исправлено смещение для Y в VBE)
  mov [screen_info + 6], ax
  mov ax, [vbe_info_block + 0x10]   ; LinBytesPerScanLine (pitch)
  mov [screen_info + 8], ax

  ; 4. Переход в Protected Mode
  cli
  lgdt fword [gdtr]
  lidt fword [idtr]
  mov eax, cr0
  or al, 1
  mov cr0, eax
  jmp 0x10:pm_start

.vesa_error:
  mov ah, 0x0E
  mov al, 'E'
  int 0x10
  jmp $

use32
pm_start:
  mov ax, 0x8
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov esp, 0x90000

  ; === PAGING (Таблицы по адресу 0x100000) ===
  ; 1. Очищаем Page Directory
  mov edi, 0x100000
  xor eax, eax
  mov ecx, 1024
  rep stosd

  ; 2. Page Table для первых 4 МБ (код ядра, стек)
  mov edi, 0x101000
  mov eax, 0x00000003
  mov ecx, 1024
.fill_pt:
  mov [edi], eax
  add eax, 0x1000
  add edi, 4
  loop .fill_pt

  ; 3. Записываем первую Page Table в Page Directory (индекс 0)
  mov edi, 0x100000
  mov eax, 0x101003
  mov [edi], eax

  ; 4. Мапим видеопамять (виртуальный адрес 0xE0000000 -> индекс 896 в Page Directory)
  mov eax, 0x102003
  mov [edi + 896 * 4], eax

  ; 5. Заполняем ПЕРВУЮ Page Table для видеопамяти (0x102000) — первые 4 МБ
  mov edi, 0x102000
  mov eax, [screen_info]  
  or eax, 0x00000003
  mov ecx, 1024
.fill_pt_video1:
  mov [edi], eax
  add eax, 0x1000
  add edi, 4
  loop .fill_pt_video1

  ; 5.2 ВТОРАЯ Page Table для видеопамяти (0x103000) — еще 4 МБ (всего 8 МБ)
  ; ИСПРАВЛЕНО: Записываем адрес второй таблицы строго в Page Directory (индекс 897)
  mov eax, 0x103003
  mov [0x100000 + 897 * 4], eax   

  mov edi, 0x103000
  mov ecx, 1024
.fill_pt_video2:
  mov [edi], eax
  add eax, 0x1000
  add edi, 4
  loop .fill_pt_video2

  ; 6. Включаем Paging
  mov eax, 0x100000
  mov cr3, eax
  mov eax, cr0
  or eax, 0x80000000
  mov cr0, eax

  ; 7. Прыжок в ядро, передаем адрес структуры screen_info в ESI
  mov esi, screen_info
  jmp 0x10:0x8000

; --- Данные загрузчика ---
gdtr:       dw 24-1
            dd 0x5000
idtr:       dw 256*8-1
            dw 0x2000

align 4
screen_info:
    .lfb     dd 0
    .width   dw 0
    .height  dw 0
    .pitch   dw 0

align 16
vbe_info_block: times 512 db 0

TIMES 1024-($-$$) db 0
