#include <conio.h>
#include <dos.h>
#include <bios.h>

#define FACTOR 0.008241758242
#define PORT 0x3ee
void waitfortik(void)
{
  while ((inportb(PORT)&0x20)==0) if (kbhit()) return;
  while (inportb(PORT)&0x20) if (kbhit()) return;
}

void main()
{
	int tikken=0;
	long t,t0;
	t=biostime(0,0L);
	cprintf("\n\n\r");
  while (!kbhit())
	{
		t0=t;
		waitfortik();
		tikken++;
		t=biostime(0,0L);
		cprintf("\r%5d : %5d clockticks\n",tikken,t-t0);

  }
}
