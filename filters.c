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

  i_copyto(im, &new_im, 0, 0, (int)im->xsize, (int)im->ysize, 0, 0, NULL);
  
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

/* These functions written by Arnar M. Hrafnkelsson (mbl.is) */

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

