#include "image.h"
#include <stdlib.h>
#include <math.h>

/* These functions written by Claes Jacobson (Vogon) */

void i_contrast(i_img *im, float intensity) {
  int x, y;
  unsigned char ch;
  unsigned int new_color;
  i_color rcolor;
  
  mm_log((1,"i_contrast(im *0x%x, intensity %f)\n", im, intensity));
  
  if(intensity < 0) {
    return;
  }
  
  for(y = 0; y < im->ysize; y++) {
    for(x = 0; x < im->xsize; x++) {
      i_gpix(im, x, y, &rcolor);
      
      for(ch = 0; ch < im->channels; ch++) {
	new_color = (unsigned int) rcolor.channel[ch];
	new_color *= intensity;
	
	if(new_color > 255) {
	  new_color = 255;
	}
	
	rcolor.channel[ch] = (unsigned char) new_color;
      }
      
      i_ppix(im, x, y, &rcolor);
    }
  }  
}

void i_hardinvert(i_img *im) {
  int x, y;
  unsigned char ch;
  
  i_color rcolor;
  
    mm_log((1,"i_hardinvert(im *0x%x)\n", im));

  for(y = 0; y < im->ysize; y++) {
    for(x = 0; x < im->xsize; x++) {
      i_gpix(im, x, y, &rcolor);
      
      for(ch = 0; ch < im->channels; ch++) {
	rcolor.channel[ch] = 255 - rcolor.channel[ch];
      }
      
      i_ppix(im, x, y, &rcolor);
    }
  }  
}


void i_noise(i_img *im, float amount, unsigned char type) {
  int x, y;
  unsigned char ch;
  int new_color;
  float damount = amount * 2;
  i_color rcolor;
  int color_inc;
  
  mm_log((1,"i_noise(im *0x%x, intensity %f\n", im, amount));
  
  if(amount < 0) return;
  
  for(y = 0; y < im->ysize; y++) for(x = 0; x < im->xsize; x++) {
    i_gpix(im, x, y, &rcolor);
    
    if(type == 0) {
      color_inc = (amount - (damount * ((float)random() / RAND_MAX)));
    }
    
    for(ch = 0; ch < im->channels; ch++) {
      new_color = (int) rcolor.channel[ch];
      
      if(type != 0) {
	new_color += (amount - (damount * ((float)random() / RAND_MAX)));
      } else {
	new_color += color_inc;
      }
      
      if(new_color < 0) {
	new_color = 0;
      }
      if(new_color > 255) {
	new_color = 255;
      }
      
      rcolor.channel[ch] = (unsigned char) new_color;
    }
    
    i_ppix(im, x, y, &rcolor);
  }
}

/*
Apply image filter

im	the image
add_im	the image to add
mode	0	Normal	
	1	Multiply
	2	Screen
	3	Overlay
	4	Soft Light
	5	Hard Light
	6	Color dodge
	7	Color Burn
	8	Darker
	9	Lighter
	10	Add
	11	Subtract
	12	Difference
	13	Exclusion
	
Description:
Apply's an image onto another 
*/

void i_applyimage(i_img *im, i_img *add_im, unsigned char mode) {
  int x, y;
  int mx, my;
  i_color src_color, dst_color;

  mm_log((1, "i_applyimage(im *0x%x, add_im *0x%x, mode %d", im, add_im, mode));
  
  mx = (add_im->xsize <= im->xsize) ? add_im->xsize : add_im->xsize;
  my = (add_im->ysize <= im->ysize) ? add_im->ysize : add_im->ysize;
  
  for(x = 0; x < mx; x++) {		
    for(y = 0; y < my; y++) {
    }
  }
}
  
/* Bump map filter */

void i_bumpmap(i_img *im, i_img *bump, int channel, int light_x, int light_y, int st) {
  int x, y, ch;
  int mx, my;
  i_color x1_color, y1_color, x2_color, y2_color, dst_color;
  double nX, nY, lX, lY;
  double tX, tY, tZ;
  double aX, aY, aL;
  double fZ;
  unsigned char px1, px2, py1, py2;
  double kx, ky;

  i_img new_im;

  mm_log((1, "channels: %d\n", bump->channels));

  if(channel > bump->channels) {
    return;
  }

  mm_log((1, "i_applyimage(im *0x%x, add_im *0x%x, mode %d\n", im, bump, channel));
  
  mx = (bump->xsize <= im->xsize) ? bump->xsize : im->xsize;
  my = (bump->ysize <= im->ysize) ? bump->ysize : im->ysize;

  i_img_empty_ch(&new_im, im->xsize, im->ysize, im->channels);
 
  aX = (light_x > (mx >> 1)) ? light_x : mx - light_x;
  aY = (light_y > (my >> 1)) ? light_y : my - light_y;

  aL = sqrt((aX * aX) + (aY * aY));

  for(y = 1; y < my - 1; y++) {		
    for(x = 1; x < mx - 1; x++) {
      i_gpix(bump, x + st, y, &x1_color);
      i_gpix(bump, x, y + st, &y1_color);
      i_gpix(bump, x - st, y, &x2_color);
      i_gpix(bump, x, y - st, &y2_color);

      i_gpix(im, x, y, &dst_color);

      px1 = x1_color.channel[channel];
      py1 = y1_color.channel[channel];
      px2 = x2_color.channel[channel];
      py2 = y2_color.channel[channel];

      nX = px1 - px2;
      nY = py1 - py2;

      nX += 128;
      nY += 128;

      fZ = (sqrt((nX * nX) + (nY * nY)) / aL);
 
      tX = abs(x - light_x) / aL;
      tY = abs(y - light_y) / aL;

      tZ = 1 - (sqrt((tX * tX) + (tY * tY)) * fZ);
      
      if(tZ < 0) {
	tZ = 0;
      }

      if(tZ > 2) {
	tZ = 2;
      }

      for(ch = 0; ch < im->channels; ch++) {
	dst_color.channel[ch] = (unsigned char) (float)(dst_color.channel[ch] * tZ);
      }
      
      i_ppix(&new_im, x, y, &dst_color);
    }
  }

  i_copyto(im, &new_im, 0, 0, (int)im->xsize, (int)im->ysize, 0, 0);
  
  i_img_exorcise(&new_im);
}

/*
Filter postlevels

Description:
makes image look like modern art

the pixels r,g,b values are change to the nearest level where a level is 255 / levels
*/

void i_postlevels(i_img *im, int levels) {
  int x, y, ch;
  float pv;
  int rv;
  float av;

  i_color rcolor;

  rv = (int) ((float)(256 / levels));
  av = (float)levels;

  for(x = 0; x < im->xsize; x++) {
    for(y = 0; y < im->ysize; y++) {
      i_gpix(im, x, y, &rcolor);

      for(ch = 0; ch < im->channels; ch++) {
	pv = (((float)rcolor.channel[ch] / 255)) * av;
      
	pv = (int) ((int)pv * rv);

	if(pv < 0) {
	  pv = 0;
	} else if(pv > 255) {
	  pv = 255;
	}

	rcolor.channel[ch] = (unsigned char) pv;
      }
      
      i_ppix(im, x, y, &rcolor);
    }
  }
}

void i_mosaic(i_img *im, int size) {
  int x, y, ch;
  int lx, ly, z;
  float nc;
  long sqrsize;

  i_img new_im;
  i_color rcolor;
  long col[256];
  
  sqrsize = size * size;
  
  for(x = 0; x < im->xsize; x += size) {
    for(y = 0; y < im->ysize; y += size) {
      for(z = 0; z < 256; z++) {
	col[z] = 0;
      }
      
      for(lx = 0; lx < size; lx++) {
	for(ly = 0; ly < size; ly++) {
	  i_gpix(im, (x + lx), (y + ly), &rcolor);
	  
	  for(ch = 0; ch < im->channels; ch++) {
	    col[ch] += rcolor.channel[ch];
	  }
	}
      }
      
      for(ch = 0; ch < im->channels; ch++) {
	rcolor.channel[ch] = (int) ((float)col[ch] / sqrsize);
      }

      for(lx = 0; lx < size; lx++) {
	for(ly = 0; ly < size; ly++) {
	  i_ppix(im, (x + lx), (y + ly), &rcolor);	  
	}
      }      
    }
  }
}




unsigned char saturate(int in) {
  if (in>255) { return 255; }
  else if (in>0) return in;
  return 0;
}

/* These functions written by Arnar M. Hrafnkelsson (addi@umich.edu) */

void
i_watermark(i_img *im,i_img *wmark,int tx,int ty,int pixdiff) {
  int vx,vy,ch;
  i_color val,wval;
  for(vx=0;vx<128;vx++) for(vy=0;vy<110;vy++) {
    
    i_gpix(im,tx+vx,ty+vy,&val);
    i_gpix(im,vx,vy,&wval);
    
    for(ch=0;ch<im->channels;ch++) val.channel[ch]=saturate(val.channel[ch]+(pixdiff*(wval.channel[0]-128))/128);
    
    i_ppix(im,tx+vx,ty+vy,&val);
  }
}




void
i_autolevels(i_img *im,float lsat,float usat,float skew) {
  i_color val;
  int i,t,x,y,rhist[256],ghist[256],bhist[256];
  int rsum,rmin,rmax;
  int gsum,gmin,gmax;
  int bsum,bmin,bmax;
  int rcl,rcu,gcl,gcu,bcl,bcu;

  int rskl,rsku;
  

  mm_log((1,"i_autolevels(im *0x%X, lsat %f,usat %f,skew %f)\n", im, lsat,usat,skew));

  rsum=gsum=bsum=0;
  for(i=0;i<256;i++) rhist[i]=ghist[i]=bhist[i]=0;
  /* create histogram for each channel */
  for(y = 0; y < im->ysize; y++) for(x = 0; x < im->xsize; x++) {
    i_gpix(im, x, y, &val);
    rhist[val.channel[0]]++;
    ghist[val.channel[1]]++;
    bhist[val.channel[2]]++;
  }

  for(i=0;i<256;i++) {
    rsum+=rhist[i];
    gsum+=ghist[i];
    bsum+=bhist[i];
  }
  
  /*  printf("\n\nhistogram\n");
      for(i=0;i<256;i++) printf("%03d %03d %03d\n",rhist[i],ghist[i],bhist[i]); */
  
  rmin=gmin=bmin=0;
  rmax=gmax=bmax=255;
  
  rcu=rcl=gcu=gcl=bcu=bcl=0;
  
  for(i=0;i<256;i++) { 
    rcl+=rhist[i]; if ( (rcl<rsum*lsat) ) { rmin=i; }
    rcu+=rhist[255-i]; if ( (rcu<rsum*usat) ) { rmax=255-i; }

    gcl+=ghist[i]; if ( (gcl<gsum*lsat) ) { gmin=i; }
    gcu+=ghist[255-i]; if ( (gcu<gsum*usat) ) { gmax=255-i; }

    bcl+=bhist[i]; if ( (bcl<bsum*lsat) ) { bmin=i; }
    bcu+=bhist[255-i]; if ( (bcu<bsum*usat) ) { bmax=255-i; }
  }

  /*  printf("rmin=%d rmax=%d\n",rmin,rmax);
      printf("gmin=%d gmax=%d\n",gmin,gmax);
      printf("bmin=%d bmax=%d\n",bmin,bmax);  */

  for(y = 0; y < im->ysize; y++) for(x = 0; x < im->xsize; x++) {
    i_gpix(im, x, y, &val);
    val.channel[0]=saturate((val.channel[0]-rmin)*255/(rmax-rmin));
    val.channel[1]=saturate((val.channel[1]-gmin)*255/(gmax-gmin));
    val.channel[2]=saturate((val.channel[2]-bmin)*255/(bmax-bmin));

    /*    printf("(%d,%d) -> %f\n",x,y,PerlinNoise_2D(x,y)); */
    i_ppix(im, x, y, &val);
  }

  /*    i_ppix(im, x, y, &rcolor); */
}


/* What follows is a very bad rip of perlins 2d noise function */

float
Noise(int x, int y) {
  int n = x + y * 57; 
  n = (n<<13) ^ n;
  return ( 1.0 - ( (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0);
}

float
SmoothedNoise1(float x, float y) {
  float corners = ( Noise(x-1, y-1)+Noise(x+1, y-1)+Noise(x-1, y+1)+Noise(x+1, y+1) ) / 16;
  float sides   = ( Noise(x-1, y)  +Noise(x+1, y)  +Noise(x, y-1)  +Noise(x, y+1) ) /  8;
  float center  =  Noise(x, y) / 4;
  return corners + sides + center;
}

float C_Interpolate(float a,float b,float x) {
  /*  float ft = x * 3.1415927; */
  float ft = x * PI;
  float f = (1 - cos(ft)) * .5;
  return  a*(1-f) + b*f;
}


float
InterpolatedNoise(float x, float y) {

  int integer_X = x;
  float fractional_X = x - integer_X;
  int integer_Y = y;
  float fractional_Y = y - integer_Y;

  float v1 = SmoothedNoise1(integer_X,     integer_Y);
  float v2 = SmoothedNoise1(integer_X + 1, integer_Y);
  float v3 = SmoothedNoise1(integer_X,     integer_Y + 1);
  float v4 = SmoothedNoise1(integer_X + 1, integer_Y + 1);

  float i1 = C_Interpolate(v1 , v2 , fractional_X);
  float i2 = C_Interpolate(v3 , v4 , fractional_X);

  return C_Interpolate(i1 , i2 , fractional_Y);
}

float
PerlinNoise_2D(float x, float y) {
  int i,frequency;
  float amplitude;
  float total = 0;
  int persistence=2;
  int Number_Of_Octaves=6;
  int p = persistence;
  int n = Number_Of_Octaves - 1;

  for(i=0;i<n;i++) {
    frequency = 2*i;
    amplitude = PI;
    total = total + InterpolatedNoise(x * frequency, y * frequency) * amplitude;
  }

  return total;
}


void
i_radnoise(i_img *im,int xo,int yo,float rscale,float ascale) {
  int x,y,ch;
  i_color val;
  float pn;
  unsigned char v;
  float scale=10;
  float xc,yc,r;
  double a;
  
  for(y = 0; y < im->ysize; y++) for(x = 0; x < im->xsize; x++) {
    xc=(float)x-xo+0.5;
    yc=(float)y-yo+0.5;
    r=rscale*sqrt(xc*xc+yc*yc)+1.2;
    a=(PI+atan2(yc,xc))*ascale;
    v=saturate(128+100*(PerlinNoise_2D(a,r)));
    /* v=saturate(120+12*PerlinNoise_2D(xo+(float)x/scale,yo+(float)y/scale));  Good soft marble */ 
    for(ch=0;ch<im->channels;ch++) val.channel[ch]=v;
    i_ppix(im, x, y, &val);
  }
}

void
i_turbnoise(i_img *im,float xo,float yo,float scale) {
  int x,y,ch;
  float pn;
  unsigned char v;
  i_color val;

  /*  i_radnoise(im,250,250);
      return; */

  for(y = 0; y < im->ysize; y++) for(x = 0; x < im->xsize; x++) {
    /*    v=saturate(125*(1.0+PerlinNoise_2D(xo+(float)x/scale,yo+(float)y/scale))); */
    v=saturate(120*(1.0+sin(xo+(float)x/scale+PerlinNoise_2D(xo+(float)x/scale,yo+(float)y/scale))));
    for(ch=0;ch<im->channels;ch++) val.channel[ch]=v;
    i_ppix(im, x, y, &val);
  }
}








