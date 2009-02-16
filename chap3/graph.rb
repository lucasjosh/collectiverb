# 'Borrowed from http://github.com/alexvollmer/pci4r/tree so that I didn't need to learn the ins / outs of RMagick

class Graph
    require "rubygems"
    require "RMagick"
    
    include Magick
    
    def self.get_height(cluster)
      if cluster.right.nil? and cluster.left.nil?
        1
      else
        get_height(cluster.left) + get_height(cluster.right)
      end
    end
    
    def self.get_depth(cluster)
      if cluster.left.nil? and cluster.right.nil?
        0
      else
        [get_depth(cluster.left), get_depth(cluster.right)].max + cluster.distance
      end
    end
    
    def self.draw_dendogram(cluster, labels, file='clusters.png')
      height = get_height(cluster) * 20
      width = 2400.to_f
      depth = get_depth(cluster)
      scaling = (width - 150) / depth
 
      img = Image.new(width, height) {
        self.background_color = 'white'
      }
      
      draw = Draw.new
      draw.font = '/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf'
      draw.line(0, height / 2, 10, height / 2)
 
      # Draw the first node
      draw_node(draw, cluster, 10, height / 2, scaling, labels)
      draw.draw(img)
      img.write(file)
    end
    
    def self.draw_node(draw, cluster, x, y, scaling, labels)
      if (cluster.id < 0)
        h1 = get_height(cluster.left) * 20
        h2 = get_height(cluster.right) * 20
        top = y - (h1 + h2) / 2
        bottom = y + (h1 + h2) / 2
        
        # line length
        line_length = cluster.distance * scaling
 
        # Vertical line from cluster to it's children
        draw.line(x, top + h1 /2 , x, bottom - h2/ 2)
 
        # Horizontal line to left item
        draw.line(x, top + h1 / 2, x + line_length, top + h1 / 2)
 
        # Horizontal line to right item
        draw.line(x, bottom - h2 / 2, x + line_length, bottom - h2 / 2)
 
        # Call the function to draw the left and right nodes
        draw_node(draw, cluster.left, x+line_length, top+h1/2, scaling, labels)
        draw_node(draw, cluster.right, x+line_length, bottom-h2/2, scaling, labels)
      else
        # draw the node for the endpoint
        draw.text(x, y + 4, labels[cluster.id])
      end
    end
    
    # 3.8
    def self.draw2d(data, labels, file='/tmp/mds2d.png')
      img = Image.new(2000, 2000) {
        self.background_color = 'white'
      }
      
      draw = Draw.new
      draw.font = '/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf'
 
      data.each_with_index do |d, i|
        x = (d[0] + 0.5) * 1000
        y = (d[1] + 0.5) * 1000
        draw.text(x, y, labels[i]) unless (labels[i] =~ /\d/) == 0
      end
      
      draw.draw(img)
      img.write(file)
    end
end