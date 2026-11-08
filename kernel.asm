use32
org 0x8000

kernel:
    mov ax, 0x8
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Инициализируем VESA параметры из ESI
    call video_init
    
    ; Заливаем экран синим, как в твоем рабочем тесте
    mov ecx, 0x0000FF
    call clear_screen

    ; Рисуем BMP картинку (вызов функции)
    mov esi, bmp_data
    call draw_bmp

    jmp $

include "video.inc"

; === КАРТИНКА ===
align 16
bmp_data:
    file "image.bmp"

; === СТРОГОЕ ВЫРАВНИВАНИЕ ЯДРА (10 секторов = 5120 байт) ===
; Чтобы картинка поместилась, 10 секторов должно хватить для 8КБ изображения.
; Если вдруг FASM рухнет с ошибкой "negative bytes", просто увеличь количество секторов
; в boot.asm (например, до 30 секторов) и здесь измени цифру на 15360.
TIMES 10240-($-$$) db 0 
