/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
#include <stdint.h>
#include <stdbool.h>

#ifdef ICEBREAKER
#  define MEM_TOTAL 0x20000 /* 128 KB */
#elif HX8KDEMO
#  define MEM_TOTAL 0x200 /* 2 KB */
#else
#  error "Set -DICEBREAKER or -DHX8KDEMO when compiling firmware.c"
#endif

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;
int x ;
//int cnt = 0; //to check fifo full condition
int i =1;
uint32_t fifo_data;
#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_leds (*(volatile uint32_t*)0x03000000)

#define data_reg (*(volatile uint32_t*)0x00000110)
#define cpu_status (*(volatile uint32_t*)0x00000014)
#define cpu_status_change (*(volatile uint32_t*)0x00000018)
#define TB_status (*(volatile uint32_t*)0x0000001C)
#define TB_status_change (*(volatile uint32_t*)0x00000020)
#define cpu_result (*(volatile uint32_t*)0x00000024)
#define fifo_wr_en (*(volatile uint32_t*)0x05000004)
#define fifo2_rd_en (*(volatile uint32_t*)0x05000008)
#define fifo_base 0x00000028
#define SRAM_W(base,offset) (*(volatile uint32_t*)((base)+(offset)))
extern uint32_t flashio_worker_end;
static uint32_t seed = 12345;  // Initial seed
uint32_t rand_riscv() {
    seed = (1103515245 * seed + 12345) & 0x0000000F; // Simple LCG
    return seed;
}


#define FIFO_DEPTH 8  
#define DATA_WIDTH 32 
// --------------------------------------------------------

extern uint32_t flashio_worker_begin;


void flashio(uint8_t *data, int len, uint8_t wrencmd)
{
	uint32_t func[&flashio_worker_end - &flashio_worker_begin];

	uint32_t *src_ptr = &flashio_worker_begin;
	uint32_t *dst_ptr = func;

	while (src_ptr != &flashio_worker_end)
		*(dst_ptr++) = *(src_ptr++);

	((void(*)(uint8_t*, uint32_t, uint32_t))func)(data, len, wrencmd);
}

#ifdef HX8KDEMO
void set_flash_qspi_flag()
{
	uint8_t buffer[8];
	uint32_t addr_cr1v = 0x800002;

	// Read Any Register (RDAR 65h)
	buffer[0] = 0x65;
	buffer[1] = addr_cr1v >> 16;
	buffer[2] = addr_cr1v >> 8;
	buffer[3] = addr_cr1v;
	buffer[4] = 0; // dummy
	buffer[5] = 0; // rdata
	flashio(buffer, 6, 0);
	uint8_t cr1v = buffer[5];

	// Write Enable (WREN 06h) + Write Any Register (WRAR 71h)
	buffer[0] = 0x71;
	buffer[1] = addr_cr1v >> 16;
	buffer[2] = addr_cr1v >> 8;
	buffer[3] = addr_cr1v;
	buffer[4] = cr1v | 2; // Enable QSPI
	flashio(buffer, 5, 0x06);
}

void set_flash_latency(uint8_t value)
{
	reg_spictrl = (reg_spictrl & ~0x007f0000) | ((value & 15) << 16);

	uint32_t addr = 0x800004;
	uint8_t buffer_wr[5] = {0x71, addr >> 16, addr >> 8, addr, 0x70 | value};
	flashio(buffer_wr, 5, 0x06);
}

void set_flash_mode_spi()
{
	reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00000000;
}

void set_flash_mode_dual()
{
	reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00400000;
}

void set_flash_mode_quad()
{
	reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00200000;
}

void set_flash_mode_qddr()
{
	reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00600000;
}
#endif

#ifdef ICEBREAKER
void set_flash_qspi_flag()
{
	uint8_t buffer[8];

	// Read Configuration Registers (RDCR1 35h)
	buffer[0] = 0x35;
	buffer[1] = 0x00; // rdata
	flashio(buffer, 2, 0);
	uint8_t sr2 = buffer[1];

	// Write Enable Volatile (50h) + Write Status Register 2 (31h)
	buffer[0] = 0x31;
	buffer[1] = sr2 | 2; // Enable QSPI
	flashio(buffer, 2, 0x50);
}

void set_flash_mode_spi()
{
	reg_spictrl = (reg_spictrl & ~0x007f0000) | 0x00000000;
}

void set_flash_mode_dual()
{
	reg_spictrl = (reg_spictrl & ~0x007f0000) | 0x00400000;
}

void set_flash_mode_quad()
{
	reg_spictrl = (reg_spictrl & ~0x007f0000) | 0x00240000;
}

void set_flash_mode_qddr()
{
	reg_spictrl = (reg_spictrl & ~0x007f0000) | 0x00670000;
}

void enable_flash_crm()
{
	reg_spictrl |= 0x00100000;
}
#endif

// --------------------------------------------------------

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4*i)) & 15];
		if (c == '0' && i >= digits) continue;
		putchar(c);
		digits = i;
	}
}

void print_dec(uint32_t v)
{
	if (v >= 1000) {
		print(">=1000");
		return;
	}

	if      (v >= 900) { putchar('9'); v -= 900; }
	else if (v >= 800) { putchar('8'); v -= 800; }
	else if (v >= 700) { putchar('7'); v -= 700; }
	else if (v >= 600) { putchar('6'); v -= 600; }
	else if (v >= 500) { putchar('5'); v -= 500; }
	else if (v >= 400) { putchar('4'); v -= 400; }
	else if (v >= 300) { putchar('3'); v -= 300; }
	else if (v >= 200) { putchar('2'); v -= 200; }
	else if (v >= 100) { putchar('1'); v -= 100; }

	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }

	if      (v >= 9) { putchar('9'); v -= 9; }
	else if (v >= 8) { putchar('8'); v -= 8; }
	else if (v >= 7) { putchar('7'); v -= 7; }
	else if (v >= 6) { putchar('6'); v -= 6; }
	else if (v >= 5) { putchar('5'); v -= 5; }
	else if (v >= 4) { putchar('4'); v -= 4; }
	else if (v >= 3) { putchar('3'); v -= 3; }
	else if (v >= 2) { putchar('2'); v -= 2; }
	else if (v >= 1) { putchar('1'); v -= 1; }
	else putchar('0');
}

char getchar_prompt(char *prompt)
{
	int32_t c = -1;

	uint32_t cycles_begin, cycles_now, cycles;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

	reg_leds = ~0;

	if (prompt)
		print(prompt);

	while (c == -1) {
		__asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
		cycles = cycles_now - cycles_begin;
		if (cycles > 12000000) {
			if (prompt)
				print(prompt);
			cycles_begin = cycles_now;
			reg_leds = ~reg_leds;
		}
		c = reg_uart_data;
	}

	reg_leds = 0;
	return c;
}

char getchar()
{
	return getchar_prompt(0);
}

void cmd_print_spi_state()
{
	print("SPI State:\n");

	print("  LATENCY ");
	print_dec((reg_spictrl >> 16) & 15);
	print("\n");

	print("  DDR ");
	if ((reg_spictrl & (1 << 22)) != 0)
		print("ON\n");
	else
		print("OFF\n");

	print("  QSPI ");
	if ((reg_spictrl & (1 << 21)) != 0)
		print("ON\n");
	else
		print("OFF\n");

	print("  CRM ");
	if ((reg_spictrl & (1 << 20)) != 0)
		print("ON\n");
	else
		print("OFF\n");
}

uint32_t xorshift32(uint32_t *state)
{
	/* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;

	return x;
}

void cmd_memtest()
{
	int cyc_count = 5;
	int stride = 256;
	uint32_t state;

	volatile uint32_t *base_word = (uint32_t *) 0;
	volatile uint8_t *base_byte = (uint8_t *) 0;

	print("Running memtest ");

	// Walk in stride increments, word access
	for (int i = 1; i <= cyc_count; i++) {
		state = i;

		for (int word = 0; word < MEM_TOTAL / sizeof(int); word += stride) {
			*(base_word + word) = xorshift32(&state);
		}

		state = i;

		for (int word = 0; word < MEM_TOTAL / sizeof(int); word += stride) {
			if (*(base_word + word) != xorshift32(&state)) {
				print(" ***FAILED WORD*** at ");
				print_hex(4*word, 4);
				print("\n");
				return;
			}
		}

		print(".");
	}

	// Byte access
	for (int byte = 0; byte < 128; byte++) {
		*(base_byte + byte) = (uint8_t) byte;
	}

	for (int byte = 0; byte < 128; byte++) {
		if (*(base_byte + byte) != (uint8_t) byte) {
			print(" ***FAILED BYTE*** at ");
			print_hex(byte, 4);
			print("\n");
			return;
		}
	}

	print(" passed\n");
}

// --------------------------------------------------------

void cmd_read_flash_id()
{
	uint8_t buffer[17] = { 0x9F, /* zeros */ };
	flashio(buffer, 17, 0);

	for (int i = 1; i <= 16; i++) {
		putchar(' ');
		print_hex(buffer[i], 2);
	}
	putchar('\n');
}

// --------------------------------------------------------

#ifdef HX8KDEMO
uint8_t cmd_read_flash_regs_print(uint32_t addr, const char *name)
{
	set_flash_latency(8);

	uint8_t buffer[6] = {0x65, addr >> 16, addr >> 8, addr, 0, 0};
	flashio(buffer, 6, 0);

	print("0x");
	print_hex(addr, 6);
	print(" ");
	print(name);
	print(" 0x");
	print_hex(buffer[5], 2);
	print("\n");

	return buffer[5];
}

void cmd_read_flash_regs()
{
	print("\n");
	uint8_t sr1v = cmd_read_flash_regs_print(0x800000, "SR1V");
	uint8_t sr2v = cmd_read_flash_regs_print(0x800001, "SR2V");
	uint8_t cr1v = cmd_read_flash_regs_print(0x800002, "CR1V");
	uint8_t cr2v = cmd_read_flash_regs_print(0x800003, "CR2V");
	uint8_t cr3v = cmd_read_flash_regs_print(0x800004, "CR3V");
	uint8_t vdlp = cmd_read_flash_regs_print(0x800005, "VDLP");
}
#endif

#ifdef ICEBREAKER
uint8_t cmd_read_flash_reg(uint8_t cmd)
{
	uint8_t buffer[2] = {cmd, 0};
	flashio(buffer, 2, 0);
	return buffer[1];
}

void print_reg_bit(int val, const char *name)
{
	for (int i = 0; i < 12; i++) {
		if (*name == 0)
			putchar(' ');
		else
			putchar(*(name++));
	}

	putchar(val ? '1' : '0');
	putchar('\n');
}

void cmd_read_flash_regs()
{
	putchar('\n');

	uint8_t sr1 = cmd_read_flash_reg(0x05);
	uint8_t sr2 = cmd_read_flash_reg(0x35);
	uint8_t sr3 = cmd_read_flash_reg(0x15);

	print_reg_bit(sr1 & 0x01, "S0  (BUSY)");
	print_reg_bit(sr1 & 0x02, "S1  (WEL)");
	print_reg_bit(sr1 & 0x04, "S2  (BP0)");
	print_reg_bit(sr1 & 0x08, "S3  (BP1)");
	print_reg_bit(sr1 & 0x10, "S4  (BP2)");
	print_reg_bit(sr1 & 0x20, "S5  (TB)");
	print_reg_bit(sr1 & 0x40, "S6  (SEC)");
	print_reg_bit(sr1 & 0x80, "S7  (SRP)");
	putchar('\n');

	print_reg_bit(sr2 & 0x01, "S8  (SRL)");
	print_reg_bit(sr2 & 0x02, "S9  (QE)");
	print_reg_bit(sr2 & 0x04, "S10 ----");
	print_reg_bit(sr2 & 0x08, "S11 (LB1)");
	print_reg_bit(sr2 & 0x10, "S12 (LB2)");
	print_reg_bit(sr2 & 0x20, "S13 (LB3)");
	print_reg_bit(sr2 & 0x40, "S14 (CMP)");
	print_reg_bit(sr2 & 0x80, "S15 (SUS)");
	putchar('\n');

	print_reg_bit(sr3 & 0x01, "S16 ----");
	print_reg_bit(sr3 & 0x02, "S17 ----");
	print_reg_bit(sr3 & 0x04, "S18 (WPS)");
	print_reg_bit(sr3 & 0x08, "S19 ----");
	print_reg_bit(sr3 & 0x10, "S20 ----");
	print_reg_bit(sr3 & 0x20, "S21 (DRV0)");
	print_reg_bit(sr3 & 0x40, "S22 (DRV1)");
	print_reg_bit(sr3 & 0x80, "S23 (HOLD)");
	putchar('\n');
}
#endif

// --------------------------------------------------------

uint32_t cmd_benchmark(bool verbose, uint32_t *instns_p)
{
	uint8_t data[256];
	uint32_t *words = (void*)data;

	uint32_t x32 = 314159265;

	uint32_t cycles_begin, cycles_end;
	uint32_t instns_begin, instns_end;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_begin));

	for (int i = 0; i < 20; i++)
	{
		for (int k = 0; k < 256; k++)
		{
			x32 ^= x32 << 13;
			x32 ^= x32 >> 17;
			x32 ^= x32 << 5;
			data[k] = x32;
		}

		for (int k = 0, p = 0; k < 256; k++)
		{
			if (data[k])
				data[p++] = k;
		}

		for (int k = 0, p = 0; k < 64; k++)
		{
			x32 = x32 ^ words[k];
		}
	}

	__asm__ volatile ("rdcycle %0" : "=r"(cycles_end));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_end));

	if (verbose)
	{
		print("Cycles: 0x");
		print_hex(cycles_end - cycles_begin, 8);
		putchar('\n');

		print("Instns: 0x");
		print_hex(instns_end - instns_begin, 8);
		putchar('\n');

		print("Chksum: 0x");
		print_hex(x32, 8);
		putchar('\n');
	}

	if (instns_p)
		*instns_p = instns_end - instns_begin;

	return cycles_end - cycles_begin;
}

// --------------------------------------------------------

#ifdef HX8KDEMO
void cmd_benchmark_all()
{
	uint32_t instns = 0;

	print("default        ");
	reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00000000;
	print(": ");
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	for (int i = 8; i > 0; i--)
	{
		print("dspi-");
		print_dec(i);
		print("         ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00400000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	for (int i = 8; i > 0; i--)
	{
		print("dspi-crm-");
		print_dec(i);
		print("     ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00500000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	for (int i = 8; i > 0; i--)
	{
		print("qspi-");
		print_dec(i);
		print("         ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00200000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	for (int i = 8; i > 0; i--)
	{
		print("qspi-crm-");
		print_dec(i);
		print("     ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00300000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	for (int i = 8; i > 0; i--)
	{
		print("qspi-ddr-");
		print_dec(i);
		print("     ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00600000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	for (int i = 8; i > 0; i--)
	{
		print("qspi-ddr-crm-");
		print_dec(i);
		print(" ");

		set_flash_latency(i);
		reg_spictrl = (reg_spictrl & ~0x00700000) | 0x00700000;

		print(": ");
		print_hex(cmd_benchmark(false, &instns), 8);
		putchar('\n');
	}

	print("instns         : ");
	print_hex(instns, 8);
	putchar('\n');
}
#endif

#ifdef ICEBREAKER
void cmd_benchmark_all()
{
	uint32_t instns = 0;

	print("default   ");
	set_flash_mode_spi();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	print("dual      ");
	set_flash_mode_dual();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	print("quad      ");
	set_flash_mode_quad();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	print("quad-crm  ");
	enable_flash_crm();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	print("qddr      ");
	set_flash_mode_qddr();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

	print("qddr-crm  ");
	enable_flash_crm();
	print_hex(cmd_benchmark(false, &instns), 8);
	putchar('\n');

}
#endif
// --------------------------------------------------------

void cmd_echo()
{
	print("Return to menu by sending '!'\n\n");
	char c;
	while ((c = getchar()) != '!')
		putchar(c);
}
// --------------------------------------------------------

void interrupt()
	{
 	x=0;
	cpu_status=1;
	cpu_status_change=1;
	print("cpu Interrupt");
	}

// --------------------------------------------------------

void  mask_irq1()
	{
	print(" maskirq ");
	}

void  ret_irq1()
	{
	print(" retirq ");
	}

// --------------------------------------------------------

void read_from_uart()
{
	char temp;	
	cpu_status=1;
	cpu_status_change=1;
	while( TB_status != 1) { print("waiting for TB");}
	TB_status=0;
	TB_status_change=0;
	temp=getchar_prompt("Data");
	data_reg=temp;
	cpu_status=3;
	cpu_status_change=1;
	while( TB_status_change != 1) ; 
	temp=cpu_result;    
	if( temp==2)	
	print("Pass"); 
	else if(temp ==1) 
	print("Fail");	
}
// --------------------------------------------------------

void write_to_uart()
{	
	uint32_t temp;
	cpu_status=1;
	cpu_status_change=1;
	while( TB_status != 1) { print("waiting for TB");}
	TB_status=0;
	TB_status_change=0;
	data_reg=8;
	cpu_status=2;
	cpu_status_change=1;
	temp = data_reg;
	print_dec(temp);
	putchar(temp);
	cpu_status=4;
	cpu_status_change=1;
}

// --------------------------------------------------------

void write_to_fifo() {

    x = 1;
    int offset = 0; // Initialize offset for SRAM writes
    TB_status_change = 0; //Reset testbench status change flag
    int flag_error = 0;  // Error flag for comparison result
   
 print("Starting FIFO write");

// Loop to write data to FIFO
    while (x) {
        SRAM_W(fifo_base, offset) = i; // Write data 'i' to SRAM at 'fifo_base' with 'offset'
        fifo_wr_en = i;
        i = i + 1;
        offset = offset + 4;
 print("Writing to SRAM: ");

    }
}

// --------------------------------------------------------
//FIFO2 Read from CPU

void read_from_fifo() {
    int offset = 0; // Initialize offset for SRAM writes
    cpu_status = 1;
    cpu_status_change = 1;

    while (TB_status != 1) {
        print("waiting for TB");
    }
    for (int i = 1; i < 9; i++) {

        fifo_data = fifo2_rd_en; // Read data from FIFO 
	print_dec(fifo_data); // Print the data read from FIFO
	SRAM_W(fifo_base, offset) = fifo_data; // Write data to SRAM
	offset = offset + 4; // Increment the offset for the next SRAM write
    }
   	// Update status to indicate the completion of the read process
    	TB_status = 0;
    	TB_status_change = 0;
    

    cpu_status = 3;
    cpu_status_change = 1;
}
// --------------------------------------------------------

void check_result() {
    int temp;
    while (TB_status_change != 1);

 print("checking result");

    temp = cpu_result;  //Read the CPU result
    if (temp == 2) {
        print(" Pass ");
    } else if (temp == 1) {
        print(" Fail ");
    }
}

// --------------------------------------------------------

void fifo1_full_test(){
    x=1;
    i=1;
    while (x) {
	print_dec(i);
        fifo_wr_en = i;
        i = i + 1;
    }
}

// --------------------------------------------------------
void fifo2_empty_test() {
    int offset = 0; // Initialize offset for SRAM writes
    cpu_status = 1;
    cpu_status_change = 1;

    while (TB_status != 1) {
        print("waiting for TB");
    }
    for (int i = 0; i < 4; i++) {

        fifo_data = fifo2_rd_en; // Read data from FIFO 
	print_dec(fifo_data); // Print the data read from FIFO
	SRAM_W(fifo_base, offset) = fifo_data; // Write data to SRAM
	offset = offset + 4; // Increment the offset for the next SRAM write
    }
   	// Update status to indicate the completion of the read process
    	TB_status = 0;
    	TB_status_change = 0;
    

    cpu_status = 3;
    cpu_status_change = 1;
}
// --------------------------------------------------------

/*void delay() {
    volatile int count = 1000;
    while (count--) {
        __asm__("nop");
    }
}*/

// --------------------------------------------------------

 void fifo1_data_integrity_test() { 
    
x = 1;
    int offset = 0; // Initialize offset for SRAM writes
    TB_status_change = 0; //Reset testbench status change flag
    int flag_error = 0;  // Error flag for comparison result
    int temp;

        print("Starting FIFO1");
	i=rand_riscv();

    // Loop to write data to FIFO
    while (x) {	
	i=rand_riscv();
	print_dec(i);
        SRAM_W(fifo_base, offset) = i; // Write data 'i' to SRAM at 'fifo_base' with 'offset
        fifo_wr_en = i;
        offset = offset + 4;
	
    }
}
 
// --------------------------------------------------------

void fifo2_data_integrity_test() {

    int offset = 0; // Initialize offset for SRAM writes
    cpu_status = 1;
    cpu_status_change = 1;

    while (TB_status != 1) {
        print("waiting for TB");
    }
    for (int i = 1; i < 9; i++) {

        fifo_data = fifo2_rd_en; // Read data from FIFO 
	print_dec(fifo_data); // Print the data read from FIFO
	SRAM_W(fifo_base, offset) = fifo_data; // Write data to SRAM
	offset = offset + 4; // Increment the offset for the next SRAM write
    }
   	// Update status to indicate the completion of the read process
    	TB_status = 0;
    	TB_status_change = 0;
    

    cpu_status = 3;
    cpu_status_change = 1;
}

// --------------------------------------------------------

void uart_loop_back_test() {
	char data;
	data=getchar();
	putchar(data);
}

//--------------------------------------------------------

void main()
{	
	
	reg_uart_clkdiv = 104;	
	print("Booting..\n");

	while(1)
	{
	  char cmd;
	  cmd = getchar();
         
	  if( cmd == 13)
		break;

	  switch (cmd)
	  {
	   case 1 :
		read_from_uart();
		break;
	   case 2 :
		write_to_uart();
		break;
 	   case 3 :
		read_from_uart();
		break;
           case 4 :
                write_to_fifo(); 
		check_result();
		break;
	   case 5 :
		read_from_fifo();
		break;
	   case 6 :
		fifo1_full_test();
		break;
	   case 8:
		write_to_fifo();
                break;
	   case 9:
		fifo2_empty_test();
                break;
	   case 10 :
		fifo1_data_integrity_test();
		check_result();
                break;		
	   case 11 :
		fifo2_data_integrity_test();
                break;	
	   case 12 :
	        uart_loop_back_test();
	        break;	
	  }
	}

	//reg_leds = 63;
//	set_flash_qspi_flag();

//	reg_leds = 127;
//	while (getchar_prompt("Press ENTER to continue..\n") != '\r') { /* wait */ }

	print("\n");
	print("  ____  _          ____         ____\n");
	print(" |  _ \\(_) ___ ___/ ___|  ___  / ___|\n");
	print(" | |_) | |/ __/ _ \\___ \\ / _ \\| |\n");
	print(" |  __/| | (_| (_) |__) | (_) | |___\n");
	print(" |_|   |_|\\___\\___/____/ \\___/ \\____|\n");
	print("\n");

	print("Total memory: ");
	print_dec(MEM_TOTAL / 1024);
	print(" KiB\n");
	print("\n");
	print("\n");

	cmd_print_spi_state();
	print("\n");

	while (1)
	{
		print("\n");

		print("Select an action:\n");
		print("\n");
		print("   [1] Read SPI Flash ID\n");
		print("   [2] Read SPI Config Regs\n");
		print("   [3] Switch to default mode\n");
		print("   [4] Switch to Dual I/O mode\n");
		print("   [5] Switch to Quad I/O mode\n");
		print("   [6] Switch to Quad DDR mode\n");
		print("   [7] Toggle continuous read mode\n");
		print("   [9] Run simplistic benchmark\n");
		print("   [0] Benchmark all configs\n");
		print("   [M] Run Memtest\n");
		print("   [S] Print SPI state\n");
		print("   [e] Echo UART\n");
		print("\n");

		for (int rep = 10; rep > 0; rep--)
		{
			print("Command> ");
			char cmd = getchar();
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			print("\n");

			switch (cmd)
			{
			case '1':
				cmd_read_flash_id();
				break;
			case '2':
				cmd_read_flash_regs();
				break;
			case '3':
				set_flash_mode_spi();
				break;
			case '4':
				set_flash_mode_dual();
				break;
			case '5':
				set_flash_mode_quad();
				break;
			case '6':
				set_flash_mode_qddr();
				break;
			case '7':
				reg_spictrl = reg_spictrl ^ 0x00100000;
				break;
			case '9':
				cmd_benchmark(true, 0);
				break;
			case '0':
				cmd_benchmark_all();
				break;
			case 'M':
				cmd_memtest();
				break;
			case 'S':
				cmd_print_spi_state();
				break;
			case 'e':
				cmd_echo();
				break;
			default:
				continue;
			}

			break;
		}
	}
}
