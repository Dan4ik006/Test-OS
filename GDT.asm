;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;;
;; NEXTGEN OS,  2001. GDT. Not full.                           ;;
;; Would be chaged in next releases.                           ;;
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;;
org 0x5000

gdt:        dw 0x0000, 0x0000, 0x0000, 0x0000
sys_data:   dw 0xFFFF, 0x0000, 0x9200, 0x00CF
sys_code:   dw 0xFFFF, 0x0000, 0x9800, 0x00CF
gdt_end:

TIMES 512-($-$$) db 0