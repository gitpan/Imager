#include "image.h"
#include "gif_lib.h"
#include "gifquant.h"

/* Make some variables global, so we could access them faster: */
static int
    ImageNum = 0,
    BackGround = 0,
    OneFileFlag = FALSE,
    HelpFlag = FALSE,
    ColorMapSize = 0,
    InterlacedOffset[] = { 0, 4, 2, 1 }, /* The way Interlaced image should. */
    InterlacedJumps[] = { 8, 8, 4, 2 };    /* be read - offsets and jumps... */
static ColorMapObject
    *ColorMap;

/* static void DumpScreen2RGB(char *FileName, int OneFileFlag,
			   GifRowType *ScreenBuffer,
			   int ScreenWidth, int ScreenHeight); */


i_img *
i_readgif(i_img *im,int fd) {
  int	i, j, Error, NumFiles, Size, Row, Col, Width, Height, ExtCode, Count, x, OutFileFlag = FALSE;
  GifRecordType RecordType;
  GifByteType *Extension;
  
  /*  GifRowType *ScreenBuffer; */
  GifRowType GifRow;
  GifFileType *GifFile;
  
  static GifColorType *ColorMapEntry;
  i_color col;

  /*  unsigned char *Buffer, *BufferP; */

  mm_log((1,"i_readgif(im 0x%x, fd %d)\n",im,fd));

  if ((GifFile = DGifOpenFileHandle(fd)) == NULL) {
    m_fatal(0,"i_readgif: Unable to open file\n");
    return(0);
  }
  
  BackGround = GifFile->SBackGroundColor;
  ColorMap = (GifFile->Image.ColorMap ? GifFile->Image.ColorMap : GifFile->SColorMap);
  ColorMapSize = ColorMap->ColorCount;

  im=i_img_empty_ch(im,GifFile->SWidth,GifFile->SHeight,3);
  
  Size = GifFile->SWidth * sizeof(GifPixelType); 
  
  if ((GifRow = (GifRowType) mymalloc(Size)) == NULL)
    m_fatal(0,"Failed to allocate memory required, aborted."); /* First row. */

  for (i = 0; i < GifFile->SWidth; i++) GifRow[i] = GifFile->SBackGroundColor;
  
  /* Scan the content of the GIF file and load the image(s) in: */
  do {
    if (DGifGetRecordType(GifFile, &RecordType) == GIF_ERROR) {
      PrintGifError();
      exit(-1);
    }
    
    switch (RecordType) {
    case IMAGE_DESC_RECORD_TYPE:
      if (DGifGetImageDesc(GifFile) == GIF_ERROR) {
	PrintGifError();
	exit(-1);
      }
      Row = GifFile->Image.Top; /* Image Position relative to Screen. */
      Col = GifFile->Image.Left;
      Width = GifFile->Image.Width;
      Height = GifFile->Image.Height;
      ImageNum++;
      mm_log((1,"i_readgif: Image %d at (%d, %d) [%dx%d]: \n",ImageNum, Col, Row, Width, Height));

      if (GifFile->Image.Left + GifFile->Image.Width > GifFile->SWidth ||
	  GifFile->Image.Top + GifFile->Image.Height > GifFile->SHeight) {
	fprintf(stderr, "Image %d is not confined to screen dimension, aborted.\n");
	return(0);
      }
      if (GifFile->Image.Interlace) {

	for (Count = i = 0; i < 4; i++) for (j = Row + InterlacedOffset[i]; j < Row + Height; j += InterlacedJumps[i]) {
	  Count++;
	  if (DGifGetLine(GifFile, &GifRow[Col], Width) == GIF_ERROR) {
	    mm_log((1,"fatal"));
	    exit(-1);
	  }
	  
	  for (x = 0; x < GifFile->SWidth; x++) {
	    ColorMapEntry = &ColorMap->Colors[GifRow[x]];
	    col.rgb.r = ColorMapEntry->Red;
	    col.rgb.g = ColorMapEntry->Green;
	    col.rgb.b = ColorMapEntry->Blue;
	    i_ppix(im,x,Row,&col);
	  }
	  
	}
      }
      else {
	for (i = 0; i < Height; i++) {
	  if (DGifGetLine(GifFile, &GifRow[Col], Width) == GIF_ERROR) {
	    mm_log((1,"fatal\n"));
	    exit(-1);
	  }

	  for (x = 0; x < GifFile->SWidth; x++) {
	    ColorMapEntry = &ColorMap->Colors[GifRow[x]];
	    col.rgb.r = ColorMapEntry->Red;
	    col.rgb.g = ColorMapEntry->Green;
	    col.rgb.b = ColorMapEntry->Blue;
	    i_ppix(im,x,Row,&col);
	  }
	  Row++;
	}
      }
      break;
    case EXTENSION_RECORD_TYPE:
      /* Skip any extension blocks in file: */
      if (DGifGetExtension(GifFile, &ExtCode, &Extension) == GIF_ERROR) {
	mm_log((1,"fatal\n"));
	exit(-1);
      }
      while (Extension != NULL) {
	if (DGifGetExtensionNext(GifFile, &Extension) == GIF_ERROR) {
	  mm_log((1,"fatal\n"));
	  exit(-1);
	}
      }
      break;
    case TERMINATE_RECORD_TYPE:
      break;
    default:		    /* Should be traps by DGifGetRecordType. */
      break;
    }
  } while (RecordType != TERMINATE_RECORD_TYPE);
  
  myfree(GifRow);
  
  if (DGifCloseFile(GifFile) == GIF_ERROR) {
    PrintGifError();
    exit(-1);
  }
  return im;
}






undef_int
i_writegif(i_img *im,int fd,int colors,int pixdev,int fixedlen,i_color fixed[]) {
  int i;
  int Error, NumFiles, SizeFlag, x,y,ColorMapSize;
  unsigned long Size;

  GifByteType *RedBuffer = NULL, *GreenBuffer = NULL, *BlueBuffer = NULL,*OutputBuffer = NULL;
  GifByteType *RedP, *GreenP, *BlueP;
  ColorMapObject *OutputColorMap = NULL;
  GifFileType *GifFile;
  GifByteType *Ptr;
  
  i_color col;
  
  mm_log((1,"i_writegif(0x%x, fd %d, colors %d, pixdev %d, fixedlen %d, fixed 0x%X)\n",im,fd,colors,pixdev,fixedlen,fixed));

  if (!(im->channels==3)) m_fatal(0,"Unable to write gif, improper colorspace.\n");
  
  ColorMapSize = 1 << colors;

  Size = ((long) im->xsize) * im->ysize * sizeof(GifByteType);
  
  if ((OutputColorMap = MakeMapObject(ColorMapSize, NULL)) == NULL) m_fatal(0,"Failed to allocate memory for Output colormap.");
  if ((OutputBuffer = (GifByteType *) mymalloc(im->xsize * im->ysize * sizeof(GifByteType))) == NULL)
    m_fatal(0,"Failed to allocate memory for output buffer.");
  
  gifquant(im, &ColorMapSize, OutputBuffer, OutputColorMap->Colors,pixdev,fixedlen,fixed);

  if ((GifFile = EGifOpenFileHandle(fd)) == NULL) {
    mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
    return(0);
  }
  
  if (EGifPutScreenDesc(GifFile,im->xsize, im->ysize, colors, 0,OutputColorMap) == GIF_ERROR ||
      EGifPutImageDesc(GifFile,0, 0, im->xsize, im->ysize, FALSE, NULL) == GIF_ERROR) {
    mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
    if (GifFile != NULL) EGifCloseFile(GifFile);
    return(0);
  }
  
  Ptr = OutputBuffer;

  for (y = 0; y < im->ysize; y++) {
    if (EGifPutLine(GifFile, Ptr, im->xsize) == GIF_ERROR) {
      mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
      if (GifFile != NULL) EGifCloseFile(GifFile);
      return(0);
    }
    
    Ptr += im->xsize;
  }

  if (EGifCloseFile(GifFile) == GIF_ERROR) {
    mm_log((1,"Error in EGifCloseFile, unable to write image.\n"));
    return(0);
  }
  return(1);
}



undef_int
i_writegifmc(i_img *im,int fd,int colors) {
  int Error, NumFiles, SizeFlag, x,y,ColorMapSize;
  unsigned long Size;

  char **FileName = NULL;
  GifByteType *RedBuffer = NULL, *GreenBuffer = NULL, *BlueBuffer = NULL,*OutputBuffer = NULL;
  GifByteType *RedP, *GreenP, *BlueP;
  ColorMapObject *OutputColorMap = NULL;
  GifFileType *GifFile;
  GifByteType *Ptr;
  
  i_color col;

  mm_log((1,"i_writegif(0x%x,fd %d)\n",im,fd));
  
  if (!(im->channels==1 || im->channels==3)) { fprintf(stderr,"Unable to write gif, improper colorspace.\n"); exit(3); }
  
  ColorMapSize = 1 << colors;
  
  Size = ((long) im->xsize) * im->ysize * sizeof(GifByteType);
  
  if (im->channels == 3) {
    if ((RedBuffer   = (GifByteType *) mymalloc((unsigned int) Size)) == NULL) {
      m_fatal(0,"Failed to allocate memory required, aborted.");
      return(0);
    }
    if ((GreenBuffer = (GifByteType *) mymalloc((unsigned int) Size)) == NULL) {
      m_fatal(0,"Failed to allocate memory required, aborted.");
      free(RedBuffer);
      return(0);
    }
    
    if ((BlueBuffer  = (GifByteType *) mymalloc((unsigned int) Size)) == NULL) {
      m_fatal(0,"Failed to allocate memory required, aborted.");
      free(RedBuffer);
      free(GreenBuffer);
      return(0);
    }
    
    RedP = RedBuffer;
    GreenP = GreenBuffer;
    BlueP = BlueBuffer;
    
    for (y=0; y< im->ysize; y++) for (x=0; x < im->xsize; x++) {
      i_gpix(im,x,y,&col);
      *RedP++ = col.rgb.r;
      *GreenP++ = col.rgb.g;
      *BlueP++ = col.rgb.b;
    }
    
  } else {

    if ((RedBuffer = (GifByteType *) mymalloc((unsigned int) Size))==NULL) {
      m_fatal(0,"Failed to allocate memory required, aborted.");
      return(0);
    }

    GreenBuffer=BlueBuffer=RedBuffer;
    RedP = RedBuffer;
    for (y=0; y< im->ysize; y++) for (x=0; x < im->xsize; x++) {
      i_gpix(im,x,y,&col);
      *RedP++ = col.rgb.r;
    }
  }
  
  if ((OutputColorMap = MakeMapObject(ColorMapSize, NULL)) == NULL)
    m_fatal(0,"Failed to allocate memory for Output colormap.");
  if ((OutputBuffer = (GifByteType *) mymalloc(im->xsize * im->ysize * sizeof(GifByteType))) == NULL)
     m_fatal(0,"Failed to allocate memory for output buffer.");
  
  if (QuantizeBuffer(im->xsize, im->ysize, &ColorMapSize, RedBuffer, GreenBuffer, BlueBuffer,
		     OutputBuffer, OutputColorMap->Colors) == GIF_ERROR) {
    mm_log((1,"Error in QuantizeBuffer, unable to write image.\n"));
    return(0);
  }


  free(RedBuffer);
  if (im->channels == 3) { free(GreenBuffer); free(BlueBuffer); }
  
  if ((GifFile = EGifOpenFileHandle(fd)) == NULL) {
    mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
    return(0);
  }
  
  if (EGifPutScreenDesc(GifFile,im->xsize, im->ysize, colors, 0,OutputColorMap) == GIF_ERROR ||
      EGifPutImageDesc(GifFile,0, 0, im->xsize, im->ysize, FALSE, NULL) == GIF_ERROR) {
    mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
    if (GifFile != NULL) EGifCloseFile(GifFile);
    return(0);
  }

  Ptr = OutputBuffer;

  for (y = 0; y < im->ysize; y++) {
    if (EGifPutLine(GifFile, Ptr, im->xsize) == GIF_ERROR) {
      mm_log((1,"Error in EGifOpenFileHandle, unable to write image.\n"));
      if (GifFile != NULL) EGifCloseFile(GifFile);
      return(0);
    }
    
    Ptr += im->xsize;
  }
  
  if (EGifCloseFile(GifFile) == GIF_ERROR) {
    mm_log((1,"Error in EGifCloseFile, unable to write image.\n"));
    return(0);
  }
  return(1);
}


