/*

decrunch.asm

NMOS 6502 decompressor for data stored in tscrunch format.

This code is written for the KickAssembler assembler.

Copyright Antonio Savona 2022.

*/

.label tsget 	= $f8	//2 bytes
.label tsput 	= $fa	//2 bytes
.label tstemp	= $fc	
.label lzput 	= $fd	//2 bytes


#if RLEONLY
#else
	#define USELZ
	#define USELZ2
#endif

#define FASTDECRUNCHER // 1.5% faster, at the cost of 8 bytes of code

.macro TS_DECRUNCH(src,dst)
{
		lda #<src
		sta.zp tsget
		lda #>src
		sta.zp tsget + 1
		lda #<dst
		sta.zp tsput
		lda #>dst
		sta.zp tsput + 1
		jsr tsdecrunch
}

tsdecrunch:
{
	decrunch:
			ldy #0
	entry2:		
			lax (tsget),y
			
			bmi rleorlz
			beq done
	literal:
	#if USELZ2
			cmp #$40
			bcs lz2	
	#endif
			tay
		!:
			lda (tsget),y
			dey
			sta (tsput),y
			bne !-
			
			txa
	
			inx
	
			
	updatezp_noclc:
			adc tsput
			sta tsput
			bcs updateput_hi
		putnoof:
			txa
			adc tsget
			sta tsget
			bcc entry2
			inc tsget+1
			bcs entry2
	
			
	updateput_hi:
			inc tsput+1
			clc
			bcc putnoof
	
								
	rleorlz:
	#if USELZ
			ldx #2
			alr #$7f
			bcs ts_delz		
	//RLE
	#else
			anc #$7f		//also clears carry
	#endif
			sta tstemp		//number of bytes to de-rle
			iny
			lda (tsget),y	//fetch rle byte
			ldy tstemp
	#if FASTDECRUNCHER

			dey
			sta (tsput),y
	#endif
	ts_derle_loop:
			dey
			sta (tsput),y
			bne ts_derle_loop

			//update zero page with a = runlen, x = 2 , y = 0 
			lda tstemp

			//clc not needed as coming from anc
			bcc updatezp_noclc
			
	   done:
			rts	
	//LZ2	
	#if USELZ2	
		lz2:
			eor #$ff - $40
			adc tsput
			sta lzput
			lda tsput + 1
			sbc #0
			sta lzput + 1 		
	
			//y already zero
			
			lda (lzput),y
			sta (tsput),y
			iny		
			lda (lzput),y
			sta (tsput),y

			tya //y = a = 1. 
			tax //y = a = x = 1. a + carry = 2
			dey //ldy #0
			beq updatezp_noclc
				
	 #endif
	 				
#if USELZ
	//LZ
	ts_delz:
			
			lsr 
			sta lzto + 1
			
			iny
			
			lda tsput

			bcc long
			sbc (tsget),y
			sta lzput
			lda tsput+1
	
			sbc #$00
		
			//lz MUST decrunch forward
	lz_entry:		
			sta lzput+1
	
			dey //ldy #0
	lz_put:
	
	#if FASTDECRUNCHER
			lda (lzput),y
			sta (tsput),y
			iny
	#endif		
			lda (lzput),y
			sta (tsput),y
		!:	iny
		
			lda (lzput),y
			sta (tsput),y
			
	lzto:	cpy #0
			bne !- 
			
			tya
			
			//update zero page with a = runlen, x = 2, y = 0
			ldy #0
			//clc not needed as we have len - 1 in A (from the encoder) and C = 1
			bcs updatezp_noclc
				
	long:			
			sec 
			sbc (tsget),y
			sta lzput
			lda tsput+1
			sbc #$01
			bcs lz_entry

#endif	
}