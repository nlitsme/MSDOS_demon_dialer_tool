#include <dos.h>

int onhook=290;
int dialtone=320;
int makepulse=14;
int breakpulse=22;
int pulsepause=130;

void pickup(void)
{
  int p;
  p=inportb(0x3fc);
  if (p&1)
  {
    p&=0xfe;
    outportb(0x3fc,p);
    delay(onhook);
  }
  outportb(0x3fc,p|1);
  delay(dialtone);
}

void pulse(int n)
{
  int p;
  p=inportb(0x3fc);
  if ((p&1)==0)  pickup();
  p&=0xfe;
  while (n--)
  {
    outportb(0x3fc,p);
    delay(breakpulse);
    outportb(0x3fc,p|1);
    delay(makepulse);
  }
  delay(pulsepause);
}

void usage(void)
{
  printf("Usage: PULSE -[owmbp] number\n");
  printf("  -onnn : specify onhooktime    default : %d ms\n", onhook);
  printf("  -wnnn : specify dialtone wait default : %d ms\n", dialtone);
  printf("  -mnnn : specify make pulse    default : %d ms\n", makepulse);
  printf("  -bnnn : specify break pulse   default : %d ms\n", breakpulse);
  printf("  -pnnn : specify pulse pause   default : %d ms\n", pulsepause);
  printf("    number : 1-9, 0, a-m : pulses 1-23 pulses\n");
  printf("             ! : pickup phone\n");
}

void main(int argc, char **argv)
{
  char *p;
  while (argc>1)
  {
    if (argv[1][0]=='-')
      switch(argv[1][1])
      {
        case 'o':  onhook=atoi(argv[1]+2); break;
        case 'w':  dialtone=atoi(argv[1]+2); break;
        case 'm':  makepulse=atoi(argv[1]+2); break;
        case 'b':  breakpulse=atoi(argv[1]+2); break;
        case 'p':  pulsepause=atoi(argv[1]+2); break;
        default: usage(); return;
      }
    else
    {
      p=argv[1];
      while (*p)
      {
        switch(*p)
        {
          case '0':  pulse(10); break;
          case '1':
          case '2':
          case '3':
          case '4':
          case '5':
          case '6':
          case '7':
          case '8':
          case '9':  pulse(*p-'0'); break;

          case 'a':
          case 'b':
          case 'c':
          case 'd':
          case 'e':
          case 'f':
          case 'g':
          case 'h':
          case 'i':
          case 'j':
          case 'k':
          case 'l':
          case 'm':  pulse(*p-'a'+11); break;
          case '!':  pickup(); break;
        }
        p++;
      }
    }
    argc--;  argv++;
  }
}
