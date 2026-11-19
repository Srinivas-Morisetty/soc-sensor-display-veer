# IP Specification: Seven-Segment Display Controller (`apb_seven_seg`)
- **Base Address:** `0x8000_3000` (4 KB APB window)
- **Function:** Time-multiplexes 4 digits (`DIGIT0`–`DIGIT3`) onto shared `seg_out[7:0]` and one-hot `digit_sel[3:0]`.
- **Modes:** `CTRL[2]=0` decodes `DIGITn[3:0]` via a 7-segment BCD LUT (`0`–`F`); `CTRL[2]=1` outputs raw `DIGITn[6:0]`. `DIGITn[7]` drives decimal point `seg_out[7]`. `CTRL[1]=1` blanks all segments.
