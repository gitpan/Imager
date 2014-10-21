#include "image.h"
#include "tiffio.h"
#include "iolayer.h"



/* Compatability for 64 bit systems like latest freebsd */

static
toff_t
comp_seek(thandle_t h, toff_t o, int w) {
  io_glue *ig = (io_glue*)h;
  return (toff_t) ig->seekcb(ig, o, w);
}


/*
=item i_readtiff_wiol(i_img *im, io_glue *ig)

Retrieve an image and stores in the iolayer object.
Returns NULL on fatal error.

=cut 
*/

i_img*
i_readtiff_wiol(io_glue *ig, int length) {
  i_img *im;
  uint32 width, height;
  uint16 channels;
  uint32* raster;
  int tiled, error;
  TIFF* tif;

  error = 0;

  /* Add code to get the filename info from the iolayer */
  /* Also add code to check for mmapped code */

  io_glue_commit_types(ig);
  mm_log((1, "i_readtiff_wiol(ig 0x%p, length %d)\n", ig, length));
  
  tif = TIFFClientOpen("Iolayer: FIXME", 
		       "rm", 
		       (thandle_t) ig, 
		       (TIFFReadWriteProc) ig->readcb,
		       (TIFFReadWriteProc) ig->writecb,
		       (TIFFSeekProc) comp_seek,
		       (TIFFCloseProc) ig->closecb, 
		       (TIFFSizeProc) ig->sizecb,
		       (TIFFMapFileProc) NULL,
		       (TIFFUnmapFileProc) NULL);
  
  if (!tif) {
    mm_log((1, "i_readtiff_wiol: Unable to open tif file\n"));
    return NULL;
  }

  TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);
  TIFFGetField(tif, TIFFTAG_SAMPLESPERPIXEL, &channels);
  tiled = TIFFIsTiled(tif);

  mm_log((1, "i_readtiff_wiol: width=%d, height=%d, channels=%d\n", width, height, channels));
  mm_log((1, "i_readtiff_wiol: %stiled\n", tiled?"":"not "));
  mm_log((1, "i_readtiff_wiol: %sbyte swapped\n", TIFFIsByteSwapped(tif)?"":"not "));
  
  im = i_img_empty_ch(NULL, width, height, channels);
  
  /*   TIFFPrintDirectory(tif, stdout, 0); good for debugging */
  
  if (tiled) {
    int ok = 1;
    uint32 row, col;
    uint32 tile_width, tile_height;

    TIFFGetField(tif, TIFFTAG_TILEWIDTH, &tile_width);
    TIFFGetField(tif, TIFFTAG_TILELENGTH, &tile_height);
    mm_log((1, "i_readtiff_wiol: tile_width=%d, tile_height=%d\n", tile_width, tile_height));

    raster = (uint32*)_TIFFmalloc(tile_width * tile_height * sizeof (uint32));
    if (!raster) {
      TIFFError(TIFFFileName(tif), "No space for raster buffer");
      return NULL;
    }
    
    for( row = 0; row < height; row += tile_height ) {
      for( col = 0; ok && col < width; col += tile_width ) {
	uint32 i_row, x, newrows, newcols;

	/* Read the tile into an RGBA array */
	if (!TIFFReadRGBATile(tif, col, row, raster)) {
	  ok = 0;
	  break;
	}
	newrows = (row+tile_height > height) ? height-row : tile_height;
	mm_log((1, "i_readtiff_wiol: newrows=%d\n", newrows));
	newcols = (col+tile_width  > width ) ? width-row  : tile_width;
	for( i_row = 0; i_row < tile_height; i_row++ ) {
	  for(x = 0; x < newcols; x++) {
	    i_color val;               /* FIXME: Make sure this works everywhere */
	    val.ui = raster[x+tile_width*(tile_height-i_row-1)];
	    i_ppix(im, col+x, row+i_row, &val);
	  }
	}
      }
    }
  } else {
    uint32 rowsperstrip, row;
    TIFFGetField(tif, TIFFTAG_ROWSPERSTRIP, &rowsperstrip);
    mm_log((1, "i_readtiff_wiol: rowsperstrip=%d\n", rowsperstrip));
    
    raster = (uint32*)_TIFFmalloc(width * rowsperstrip * sizeof (uint32));
    if (!raster) {
      TIFFError(TIFFFileName(tif), "No space for raster buffer");
      return NULL;
    }
    
    for( row = 0; row < height; row += rowsperstrip ) {
      uint32 newrows, i_row;
      
      if (!TIFFReadRGBAStrip(tif, row, raster)) {
	error++;
	break;
      }
      
      newrows = (row+rowsperstrip > height) ? height-row : rowsperstrip;
      mm_log((1, "newrows=%d\n", newrows));
      
      for( i_row = 0; i_row < newrows; i_row++ ) { 
	uint32 x;
	for(x = 0; x<width; x++) {
	  i_color val;               /* FIXME: Make sure this works everywhere */
	  val.ui = raster[x+width*(newrows-i_row-1)];
	  i_ppix(im, x, i_row+row, &val);
	}
      }
    }

  }
  if (error) {
    mm_log((1, "i_readtiff_wiol: error during reading\n"));
  }
  _TIFFfree( raster );
  if (TIFFLastDirectory(tif)) mm_log((1, "Last directory of tiff file\n"));
  return im;
}



/*
=item i_writetif_wiol(i_img *im, io_glue *ig)

Stores an image in the iolayer object.

=cut 
*/


/* FIXME: Add an options array in here soonish */

undef_int
i_writetiff_wiol(i_img *im, io_glue *ig) {
  uint32 width, height;
  uint16 channels;
  uint16 predictor = 0;
  int quality = 75;
  int jpegcolormode = JPEGCOLORMODE_RGB;
  uint16 compression = COMPRESSION_PACKBITS;
  i_color val;
  uint16 photometric;
  uint32 rowsperstrip = (uint32) -1;  /* Let library pick default */
  double resolution = -1;
  unsigned char *linebuf = NULL;
  uint32 y;
  tsize_t linebytes;
  int ch, ci, rc;
  uint32 x;
  TIFF* tif;

  width    = im->xsize;
  height   = im->ysize;
  channels = im->channels;

  switch (channels) {
  case 1:
    photometric = PHOTOMETRIC_MINISBLACK;
    break;
  case 3:
    photometric = PHOTOMETRIC_RGB;
    if (compression == COMPRESSION_JPEG && jpegcolormode == JPEGCOLORMODE_RGB) photometric = PHOTOMETRIC_YCBCR;
    break;
  default:
    /* This means a colorspace we don't handle yet */
    mm_log((1, "i_writetiff_wiol: don't handle %d channel images.\n", channels));
    return 0;
  }

  /* Add code to get the filename info from the iolayer */
  /* Also add code to check for mmapped code */

  io_glue_commit_types(ig);
  mm_log((1, "i_writetiff_wiol(im 0x%p, ig 0x%p)\n", im, ig));

  /* FIXME: Enable the mmap interface */
  
  tif = TIFFClientOpen("No name", 
		       "wm", 
		       (thandle_t) ig, 
		       (TIFFReadWriteProc) ig->readcb,
		       (TIFFReadWriteProc) ig->writecb,
		       (TIFFSeekProc)      comp_seek,
		       (TIFFCloseProc)     ig->closecb, 
		       (TIFFSizeProc)      ig->sizecb,
		       (TIFFMapFileProc)   NULL,
		       (TIFFUnmapFileProc) NULL);
  
  if (!tif) {
    mm_log((1, "i_writetiff_wiol: Unable to open tif file for writing\n"));
    return 0;
  }

  mm_log((1, "i_writetiff_wiol: width=%d, height=%d, channels=%d\n", width, height, channels));
  
  if (!TIFFSetField(tif, TIFFTAG_IMAGEWIDTH,      width)   ) { mm_log((1, "i_writetiff_wiol: TIFFSetField width=%d failed\n", width)); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_IMAGELENGTH,     height)  ) { mm_log((1, "i_writetiff_wiol: TIFFSetField length=%d failed\n", height)); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, channels)) { mm_log((1, "i_writetiff_wiol: TIFFSetField samplesperpixel=%d failed\n", channels)); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_ORIENTATION,  ORIENTATION_TOPLEFT)) { mm_log((1, "i_writetiff_wiol: TIFFSetField Orientation=topleft\n")); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE,   8)        ) { mm_log((1, "i_writetiff_wiol: TIFFSetField bitpersample=8\n")); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG)) { mm_log((1, "i_writetiff_wiol: TIFFSetField planarconfig\n")); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_PHOTOMETRIC,   photometric)) { mm_log((1, "i_writetiff_wiol: TIFFSetField photometric=%d\n", photometric)); return 0; }
  if (!TIFFSetField(tif, TIFFTAG_COMPRESSION,   compression)) { mm_log((1, "i_writetiff_wiol: TIFFSetField compression=%d\n", compression)); return 0; }

  switch (compression) {
  case COMPRESSION_JPEG:
    mm_log((1, "i_writetiff_wiol: jpeg compression\n"));
    if (!TIFFSetField(tif, TIFFTAG_JPEGQUALITY, quality)        ) { mm_log((1, "i_writetiff_wiol: TIFFSetField jpegquality=%d\n", quality)); return 0; }
    if (!TIFFSetField(tif, TIFFTAG_JPEGCOLORMODE, jpegcolormode)) { mm_log((1, "i_writetiff_wiol: TIFFSetField jpegcolormode=%d\n", jpegcolormode)); return 0; }
    break;
  case COMPRESSION_LZW:
    mm_log((1, "i_writetiff_wiol: lzw compression\n"));
    break;
  case COMPRESSION_DEFLATE:
    mm_log((1, "i_writetiff_wiol: deflate compression\n"));
    if (predictor != 0) 
      if (!TIFFSetField(tif, TIFFTAG_PREDICTOR, predictor)) { mm_log((1, "i_writetiff_wiol: TIFFSetField predictor=%d\n", predictor)); return 0; }
    break;
  case COMPRESSION_PACKBITS:
    mm_log((1, "i_writetiff_wiol: packbits compression\n"));
    break;
  default:
    mm_log((1, "i_writetiff_wiol: unknown compression %d\n", compression));
    return 0;
  }
  
  linebytes = channels * width;
  linebuf = (unsigned char *)_TIFFmalloc( TIFFScanlineSize(tif) > linebytes ?
					  linebytes : TIFFScanlineSize(tif) );
  
  if (!TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, TIFFDefaultStripSize(tif, rowsperstrip))) {
    mm_log((1, "i_writetiff_wiol: TIFFSetField rowsperstrip=%d\n", rowsperstrip)); return 0; }

  TIFFGetField(tif, TIFFTAG_ROWSPERSTRIP, &rowsperstrip);
  TIFFGetField(tif, TIFFTAG_ROWSPERSTRIP, &rc);

  mm_log((1, "i_writetiff_wiol: TIFFGetField rowsperstrip=%d\n", rowsperstrip));
  mm_log((1, "i_writetiff_wiol: TIFFGetField scanlinesize=%d\n", TIFFScanlineSize(tif) ));
  mm_log((1, "i_writetiff_wiol: TIFFGetField planarconfig=%d == %d\n", rc, PLANARCONFIG_CONTIG));

  if (resolution > 0) {
    if (!TIFFSetField(tif, TIFFTAG_XRESOLUTION, resolution)) { mm_log((1, "i_writetiff_wiol: TIFFSetField Xresolution=%d\n", resolution)); return 0; }
    if (!TIFFSetField(tif, TIFFTAG_YRESOLUTION, resolution)) { mm_log((1, "i_writetiff_wiol: TIFFSetField Yresolution=%d\n", resolution)); return 0; }
    if (!TIFFSetField(tif, TIFFTAG_RESOLUTIONUNIT, RESUNIT_INCH)) {
      mm_log((1, "i_writetiff_wiol: TIFFSetField ResolutionUnit=%d\n", RESUNIT_INCH)); return 0; 
    }
  }
  
  for (y=0; y<height; y++) {
    ci = 0;
    for(x=0; x<width; x++) { 
      (void) i_gpix(im, x, y,&val);
      for(ch=0; ch<channels; ch++) linebuf[ci++] = val.channel[ch];
    }
    if (TIFFWriteScanline(tif, linebuf, y, 0) < 0) {
      mm_log((1, "i_writetiff_wiol: TIFFWriteScanline failed.\n"));
      break;
    }
  }
  (void) TIFFClose(tif);
  if (linebuf) _TIFFfree(linebuf);
  return 1;
}
