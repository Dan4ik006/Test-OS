; =============================================================================
; ДРАЙВЕР ГРАФИКИ (video.inc)
; =============================================================================
align 4
video_info:
    .lfb         dd 0
    .scr_width   dw 0
    .scr_height  dw 0
    .pitch       dw 0

temp_color dd 0

; Инициализация драйвера данными из ESI
video_init:
    mov edx, [esi]
    mov [video_info.lfb], edx
    mov cx, [esi + 4]
    mov [video_info.scr_width], cx
    mov cx, [esi + 6]
    mov [video_info.scr_height], cx
    
    mov cx, [esi + 8]
    test cx, cx
    jnz .pitch_ok
    ; Если pitch равен 0, считаем вручную: width * 4
    movzx ecx, word [video_info.scr_width]
    shl ecx, 2
.pitch_ok:
    mov [video_info.pitch], cx
    ret

; -----------------------------------------------------------------------------
; Функция: Поставить пиксель (32bpp)
; Вход: EAX = X, EBX = Y, ECX = Цвет
; -----------------------------------------------------------------------------
draw_pixel:
    push ebx
    push edx
    push edi

    cmp ax, [video_info.scr_width]
    jae .done
    cmp bx, [video_info.scr_height]
    jae .done

    push eax
    movzx eax, [video_info.pitch]
    mul ebx
    mov edi, eax
    pop eax
    
    shl eax, 2
    add edi, eax
    add edi, [video_info.lfb]
    
    mov [edi], ecx

.done:
    pop edi
    pop edx
    pop ebx
    ret

; -----------------------------------------------------------------------------
; Функция: Очистка экрана
; Вход: ECX = Цвет заливки
; -----------------------------------------------------------------------------
clear_screen:
    push eax
    push ebx
    push ecx
    push edx
    push edi

    mov edi, [video_info.lfb]
    test edi, edi
    jz .done
    
    mov [temp_color], ecx
    movzx ebx, word [video_info.scr_height]
    movzx edx, word [video_info.pitch]

.row_loop:
    movzx ecx, word [video_info.scr_width]
    push edi

.col_loop:
    mov eax, [temp_color]
    mov [edi], eax
    add edi, 4
    dec ecx
    jnz .col_loop

    pop edi
    add edi, edx
    dec ebx
    jnz .row_loop

.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; -----------------------------------------------------------------------------
; Функция: Вывод 24-битного несжатого BMP в левый верхний угол (0,0)
; Вход: ESI = адрес начала файла BMP в памяти
; -----------------------------------------------------------------------------
draw_bmp:
    pushad

    ; 1. Проверка сигнатуры 'BM'
    cmp word [esi], 0x4D42
    jne .done

    ; 2. Считываем параметры напрямую из BITMAPINFOHEADER 
    mov ebx, [esi + 18]     ; Ширина изображения
    mov ecx, [esi + 22]     ; Высота изображения
    
    test ecx, ecx
    jns .height_ok
    neg ecx
.height_ok:

    ; 3. Вычисляем шаг строки в файле (выравнивание строки BMP по 4 байта)
    mov eax, ebx
    imul eax, 3
    add eax, 3
    and eax, 0xFFFFFFFC
    mov ebp, eax            ; EBP = длина строки в файле в байтах

    ; 4. Переходим к пикселям, используя смещение из заголовка файла
    mov eax, [esi + 10]
    add esi, eax            ; ESI указывает строго на массив пикселей

    ; 5. Начинаем рисовать с нижней строки картинки (BMP хранится перевернутым)
    mov edx, ecx
    dec edx                 ; EDX = Стартовый Y на экране (например, 49 для 50х50)

    ; Наводим ESI на начало последней строки в BMP-файле
    mov eax, ecx
    dec eax
    imul eax, ebp
    add esi, eax

.row_loop:
    push ecx
    push esi

    ; Проверяем, чтобы Y не вышел за пределы экрана
    cmp edx, 0
    jl .skip_row
    movzx eax, word [video_info.scr_height]
    cmp edx, eax
    jae .skip_row

    ; Вычисляем адрес строки в линейном фреймбуфере (LFB + Y * pitch)
    movzx eax, word [video_info.pitch]
    imul eax, edx           
    add eax, [video_info.lfb]
    mov edi, eax            

    ; Попиксельное копирование текущей строки (24-бит BGR в 32-бит BGRA)
    mov ecx, ebx            
.col_loop:
    movzx eax, byte [esi]   ; Синий (B)
    mov [edi], al
    movzx eax, byte [esi+1] ; Зеленый (G)
    mov [edi+1], al
    movzx eax, byte [esi+2] ; Красный (R)
    mov [edi+2], al
    mov byte [edi+3], 0     ; Канал Alpha (заглушка)
    
    add esi, 3
    add edi, 4
    dec ecx
    jnz .col_loop

.skip_row:
    pop esi
    sub esi, ebp            ; Переходим на строку выше в файле BMP
    pop ecx

    dec edx                 ; Уменьшаем Y, двигаясь к верху экрана (строка 0)
    dec ecx                 ; Счетчик строк картинки
    jnz .row_loop

.done:
    popad
    ret
