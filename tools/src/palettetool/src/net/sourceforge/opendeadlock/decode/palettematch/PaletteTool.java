/**
* Copyright (C) 2013-2014 Tggtt <tggtt at users.sourceforge.net>
* and other OpenDeadlock members.
* 
* This file is part of OpenDeadlock (Decode/Encode Tools).
*
* OpenDeadlock is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* OpenDeadlock is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with OpenDeadlock. If not, see <http://www.gnu.org/licenses/>.
*/ 

package net.sourceforge.opendeadlock.decode.palettematch;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.Image;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferInt;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import javax.imageio.ImageIO;
import javax.swing.ImageIcon;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;

import sinai.gaspar.blackhole.Xpm;

public class PaletteTool {
	
	public static final String VERSION = "Stable 1";
	
	static String readFile(String path, Charset encoding) 
			  throws IOException 
	{
	  byte[] encoded = Files.readAllBytes(Paths.get(path));
	  return encoding.decode(ByteBuffer.wrap(encoded)).toString();
	}

	public static void main(String[] args) {
		System.out.println("Palete Tool. Version "+VERSION+'.');
		Image image = null;
		Image pal = null;		
		
		String input = null; 
		String palette = null;
		String output = null;
		int translucent = 0;
		boolean convert = false;

		if (args.length == 1)
		{
			input = args[0];
		}
		else
		if (args.length >= 3)
		{
			if (args[0].equalsIgnoreCase("convert"))
			{
				convert = true;
				output = args[2];
				palette = args[1];
				if (args.length > 4)
				{
					try 
					{
						translucent = Integer.parseInt(args[4]);
					}
					catch (NumberFormatException e)
					{
						translucent = 0;
					}
				}
			}		
			else
			if (args.length >= 4)
			{
				if (args[0].equalsIgnoreCase("match"))
				{
					input = args[2];
					output = args[3];
					palette = args[1];
					if (args.length > 4)
					{
						try 
						{
							translucent = Integer.parseInt(args[4]);
						}
						catch (NumberFormatException e)
						{
							translucent = 0;
						}
					}
				}
			}
		}

		
		try 
		{
			image = readImageFile(input);
			pal = readImageFile(palette);
		} catch (IOException e) {
			System.out.println("File read error. " + e.getMessage());
			
		}
		
		if ((pal != null) && ((image != null) ^ convert) && (output != null))
		{
			try 
			{
				if (convert)
				{
					convertPalette(translucent,pal,output);
				}
				else
				{	
					matchPalette(translucent,image,pal,output);
				}
			} catch (IOException e) {
				System.out.println("File write error. " + e.getMessage());
			}
			System.out.println("Thank you for using a tool written by Tggtt.");		
		}
		else
		{
			if (image != null && (args.length == 1))
			{
				// Use a label to display the image
				JFrame frame = new JFrame("Tggtt's Simple Image Viewer");
				JPanel mainPanel = new JPanel(new BorderLayout());
				JLabel lblimage = new JLabel(new ImageIcon(image));
				mainPanel.add(lblimage);
				// add more components here
				frame.add(mainPanel);
				frame.pack();
				frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
				frame.setLocationRelativeTo(null);
				frame.setVisible(true);
			}
			else
			{
				System.out.println("Accepted input formats: xpm, rgb formats (any permutation of 3 or 4 of these: a,r,g,b or x) gif, png, jpeg/jpg (lossy format, not recommended), bmp and wbmp.");
				System.out.println("rgb, rgba and bgrx are always read with 16 width. ");
				System.out.println("File format is guessed by its extension. ");
				System.out.println();
				System.out.println("Usage: ");
				System.out.println(" as viewer: java -jar palettetool.jar <image file> ");
				System.out.println();
				System.out.println(" as palette matcher: java -jar palettetool.jar match <Palette file> <Input> <Output> [matte index]");
				System.out.println("If the output ends in \".xpm\", a xpm file will be generated. ");
				System.out.println("If the output ends in \".bin\", a binary file will be generated. (Raw indexed without palette) ");
				System.out.println("If the output has no extension, both will be generated. ");
				System.out.println();
				System.out.println(" as palette converter: java -jar palettetool.jar convert <Palette file> <Output> [matte index]");				
				System.out.println("Output must be either xpm, or a binary rgb format. ");
				
			}
		}
	}

	private static void convertPalette(int translucent, Image pal, String output) throws IOException 
	{	
		BufferedImage palBuffer = toBufferedImage(pal);
		int[] palPixels = ((DataBufferInt) palBuffer.getRaster().getDataBuffer()).getData();
		final int width = palBuffer.getRaster().getWidth();
		final int height = palBuffer.getRaster().getHeight();
		if (output.toLowerCase().endsWith(".xpm"))
		{
			byte[][] outputIndexed = new byte[height][width];
			for (int h =0; h < height; h++)
			{
				for (int w =0; w < width; w++)
				{
					outputIndexed[h][w]=(byte) (w + (h*width));
				}
			}
			writeXpm(translucent,width*height,palPixels, width, height,outputIndexed,output);
		}
		else	
		{		
			String extension = getExtension(output);
			if (validRaw(extension,extension.length()))
			{
				byte[][] outputBin = new byte[height][width*extension.length()];
				for (int h =0; h < height; h++)
				{
					for (int w =0; w < width; w++)
					{					
						byte components[] = imageComponents(palPixels, height, h, w);
						for (int l =0; l < extension.length(); l++)
						{						
							switch (extension.charAt(l))
							{
							case 'a':
							{
								outputBin[h][(w*extension.length()+l)] = components[0];
								break;
							}
							case 'r':
							{
								outputBin[h][(w*extension.length()+l)] = components[1];
								break;
							}
							case 'g':
							{
								outputBin[h][(w*extension.length()+l)] = components[2];
								break;
							}
							case 'b':
							{
								outputBin[h][(w*extension.length()+l)] = components[3];
								break;
							}	
							default:
							{
								outputBin[h][(w*extension.length()+l)] = 0;
							}
							}								
						}					
					}
				}
				writeBin(outputBin, output);
			}
		}		
		
		
	}

	private static String getExtension(String output) {
		return output.toLowerCase().substring(1+output.lastIndexOf('.'));
	}

	private static byte[] imageComponents(int[] palPixels, final int height,
			int h, int w)
	{
		byte components[] = new byte[4];
		components[0] = (byte)((palPixels[w+(h*height)] & 0xFF000000) >> 24);
		components[1] = (byte)((palPixels[w+(h*height)] & 0x00FF0000) >> 16);
		components[2] = (byte)((palPixels[w+(h*height)] & 0x0000FF00) >> 8);
		components[3] = (byte)((palPixels[w+(h*height)] & 0x000000FF) >> 0);
		return components;
	}

	private static boolean validRaw(String extension, int size)
	{	
		int count = 0;
		for (int l = 0; l < size; l++)
		{
			final char c = extension.charAt(l);
			if (c == 'x' || c == 'a' || c == 'r' || c == 'g' || c == 'b')
			{
				count++;
			}
		}
		
		return (size >= 1) && (count == size);	
	}
	
	private static Image readImageFile(final String file) throws IOException {
		if (file != null)
		{
			Image img = null;
			if (file.toLowerCase().endsWith(".xpm"))
			{
				String content = readFile(file, Charset.defaultCharset());
				img = Xpm.XpmToImage(content);
			}
			else	
			{			
				String extension = getExtension(file);				
				final int size = extension.length();
				if (validRaw(extension,size))
				{
					
					byte[] data = readSmallBinaryFile(file);
					final int width = 16;
					final int height = (data.length/size)/16;
					if (height <= 0)
						throw new IOException("This software requires that palettes must have at least 16 items.");
					
				    img = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
				    int[] pix = ((DataBufferInt) ((BufferedImage)img).getRaster().getDataBuffer()).getData();
				    int pos = 0;
					for (int h =0; h < height; h++)
					{						
						for (int w =0; w < width; w++)
						{				
							int argb = 0;
							
							for (int l = 0; l < size; l++)
							{
								switch (extension.charAt(l))
								{
								case ('a'):
								{
									argb |= ((data[pos]) << 24) & 0xFF000000;
									break;
								}
								case ('r'):
								{
									argb |= ((data[pos]) << 16) & 0x00FF0000;
									break;
								}							
								case ('g'):
								{
									argb |= ((data[pos]) << 8) & 0x0000FF00;
									break;
								}
								case ('b'):
								{
									argb |= ((data[pos]) << 0) & 0x000000FF;
									break;
								}							
								}								
								pos++;							
							}
							pix[w + (h*width)] = argb;
						}
						
					}
				}
				else			
				{
					img = ImageIO.read(new File(file));
				}
			}
			return img;
		}
		else
			return null;
	}
	
    private static byte[] readSmallBinaryFile(String aFileName) throws IOException 
    {
	    Path path = Paths.get(aFileName);
	    return Files.readAllBytes(path);
	}
	  
	/**
	 * Converts a given Image into a BufferedImage
	 *
	 * @param img The Image to be converted
	 * @return The converted BufferedImage
	 */
	public static BufferedImage toBufferedImage(Image img)
	{
		BufferedImage bimage = null;

	    if (img instanceof BufferedImage)
	    {	    	
	    	if ((((BufferedImage)img).getType()) == BufferedImage.TYPE_INT_ARGB)
	    	{
	    		bimage = (BufferedImage)img;
	    	}
	    }
	   
	    if (bimage == null)

	    {
		    // Create a buffered image with transparency
		    bimage = new BufferedImage(img.getWidth(null), img.getHeight(null), BufferedImage.TYPE_INT_ARGB);

		    // Draw the image on to the buffered image
		    Graphics2D bGr = bimage.createGraphics();
		    bGr.drawImage(img, 0, 0, new Color(Color.TRANSLUCENT), null);
		    bGr.dispose();
	    }
	    // Return the buffered image
	    return bimage;
	}

	private static void matchPalette(int translucent, Image image, Image pal, String output) throws IOException 
	{
		BufferedImage imageBuffer = toBufferedImage(image);
		BufferedImage palBuffer = toBufferedImage(pal);
		int paletteSize = (palBuffer.getRaster().getWidth() * palBuffer.getRaster().getHeight());
		if (paletteSize > 256)
		{
			System.err.println("Invalid palette size, aborting.");
		}
		else
		{
			int[] imagePixels = ((DataBufferInt) imageBuffer.getRaster().getDataBuffer()).getData();
			int[] palPixels = ((DataBufferInt) palBuffer.getRaster().getDataBuffer()).getData();
			
			final int width = imageBuffer.getRaster().getWidth();
			final int height = imageBuffer.getRaster().getHeight();
			byte[][] outputIndexed = new byte[height][width];
			
			
			int sequential = 0;
			for (int h = 0; h < height ; h++)
			{
				for (int w = 0; w < width ; w++)
				{
					outputIndexed[h][w] = findInPalette(imagePixels[sequential],palPixels);
					sequential++;
				}		
			}
			boolean createXPM = output.endsWith(".xpm");
			boolean createBIN = output.endsWith(".bin");
			String outputxpm = output;
			String outputbin = output;
			
			if (!output.contains("."))
			{
				createXPM = true;
				createBIN = true;
				outputxpm = output+".xpm";
				outputbin = output+".bin";
			}
			if (createXPM)
			{
				writeXpm(translucent,paletteSize,palPixels, width, height,outputIndexed,outputxpm);
			}
			if (createBIN)
			{
				writeBin(outputIndexed,outputbin);				
			}				
		}
		
	}

	private static void writeBin(byte[][] outputIndexed, String output) throws IOException {

				
		File out = new File(output);
		FileOutputStream fos = new FileOutputStream(out);	
		
		for (int i = 0; i < outputIndexed.length; i++)
		{
			byte[] data = outputIndexed[i];
			fos.write(data, 0, data.length);
		}
		fos.flush();
		fos.close();
		System.out.println("Binary Output written.");		
	}

	private static void writeXpm(int translucent, int paletteSize, int[] palPixels, int width, int height, byte[][] outputIndexed,
			String output) throws IOException 
	{
		BufferedWriter writer = null;
		try 
		{
		  File out = new File(output);
		  writer = new BufferedWriter(new FileWriter(out));
		  String newline = System.getProperty("line.separator");
		  
          writer.write("/* XPM */"+newline);          
          writer.write("/* By Tggtt's Palette Matcher */"+newline);
          writer.write("static char * "+ out.getName().replace(' ', '_').replace('/', '_').replace('.', '_')  +"[] = {"+newline);
          writer.write("/* <Values> */"+newline);
          writer.write("/* <width/cols> <height/rows> <colors> <char on pixel> */"+newline);
          writer.write(String.format("\"%d %d %d 2\",",width,height,paletteSize)+newline);
          writer.write("/* <Colors> */"+newline);

          for (int p = 0 ; p < palPixels.length; p++)
          {
        	  if (p == translucent)
        	  {
        		  writer.write(String.format("\"%02x s mask c none\",",p)+newline);
        	  }
        	  else
        	  {
        		  writer.write(String.format("\"%02x c #%06x\",",p,palPixels[p]&0x00FFFFFF)+newline);
        	  }
          }
          writer.write("/* <Pixels> */"+newline);
          for (int h = 0; h < height ; )
		  {
			 writer.write("\"");
			 for (int w = 0; w < width ; w++)
			 {	
			   writer.write(String.format("%02x",outputIndexed[h][w]));
			 }
	         writer.write("\"");
			 h++;
	         if (h < (height))
	         {
	        	  writer.write(",");
	         }
	         writer.write(newline);		 
		  }        
         
          writer.write("};"+newline);
		}
		finally
		{
			if (writer != null)
			{
				writer.close();
			}
		}
		System.out.println("XPM Output written.");		
	}

	private static byte findInPalette(int c, int[] palPixels) 
	{
		byte result = 0;
		boolean matched = false;
		byte a = (byte)(c & 0xff000000);
		for (int p = 0 ; p < palPixels.length; p++)
		{	//only one alpha setting
			//if alpha is not fully transparent then require perfect match
			if (
					 ((a == 0)  && ((palPixels[p] & 0xFF000000) == 0)) 
					 || 
				     ((palPixels[p] & 0x00FFFFFF) == (c & 0x00FFFFFF))
			   )
			{				
				result = (byte)(p);
				matched = true;
				break;
			}
		}
		if (!matched)
		{
			System.out.println("Warning, unmatched color, replaced with index 0: (#AARRGGBB) "+ String.format("#%04x", c));		
		}
		
		return result;
	}

}
