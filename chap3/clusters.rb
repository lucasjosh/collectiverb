#!/usr/bin/env ruby

class BiCluster
  attr_accessor :vec, :left, :right, :vec, :id, :distance
  
  def initialize(vec, left = nil, right = nil, distance = 0.0, id = nil)
    @vec = vec
    @left = left
    @right = right
    @distance = distance
    @id = id
  end
end

def readfile(filename)
  lines = IO.readlines(filename)
  colnames = lines[0].strip.split("\t")[1...lines[0].size]
  rownames = Array.new
  data = Array.new
  lines[1...lines[0].size].each do |line|
    p = line.strip.split("\t")
    rownames << p[0]
    data << p[1...p.size].collect {|c| c.to_f}
  end
  [rownames, colnames, data]
end

def pearson(v1, v2)
  sum1 = v1.inject(0) {|sum1, n| sum1 + n}
  sum2 = v2.inject(0) {|sum2, n| sum2 + n}
  
  sum1_sq = v1.inject(0) {|sum1_sq, n| sum1_sq + n ** 2}
  sum2_sq = v2.inject(0) {|sum2_sq, n| sum2_sq + n ** 2}
  
 
  p_sum = 0
  0.upto(v1.size - 1) do |i|
    p_sum += (v1[i] * v2[i])
  end
  
  num = p_sum - (sum1*sum2/v1.size)
  den = Math.sqrt( (sum1_sq - (sum1 ** 2) / v1.size) * (sum2_sq - (sum2 ** 2) / v1.size))
  return den if den == 0
  1.0 - num / den
end

def hcluster(rows, distance = :pearson)
  distances = {}
  current_clust_id = -1
  clust = Array.new
  
  0.upto(rows.size - 1) do |i|
    clust << BiCluster.new(rows[i], nil, nil, 0.0, i)
  end
  
  while clust.size > 1
    lowestpair = [0, 1]
    closest = method(distance).call(clust[0].vec, clust[1].vec)
    
    0.upto(clust.size - 1) do |i|
      j = i + 1
      j.upto(clust.size - 1) do |ij|
        unless distances.key?([clust[i].id, clust[ij].id])
          distances[[clust[i].id, clust[ij].id]] = method(distance).call(clust[i].vec, clust[ij].vec)
        end
        d = distances[[clust[i].id, clust[ij].id]]
        
        if d < closest
          closest = d
          lowestpair = [i, ij]
        end
      end
    end
    
    mergevec = Array.new
    0.upto(clust[0].vec.size - 1) do |i|
      mergevec << (clust[lowestpair[0]].vec[i] + clust[lowestpair[1]].vec[i]) / 2.0
    end
    
    newcluster = BiCluster.new(mergevec, clust[lowestpair[0]], clust[lowestpair[1]], closest, current_clust_id)
    current_clust_id -= 1
    clust.delete_at(lowestpair[1])
    clust.delete_at(lowestpair[0])
    clust << newcluster
  end
  
  clust[0]
end

def printclust(clust, labels = nil, n = 0)
  0.upto(n) {|f| puts ' '}
  if clust.id < 0
    puts '-'
  else
    if labels.nil?
      puts clust.id
    else
      puts labels[clust.id]
    end
  end
  printclust(clust.left, labels, n+1) if clust.left
  printclust(clust.right, labels, n+1) if clust.right
  
end

def rotate_matrix(data)
  new_data = Array.new
  data.size.times do |i|
    new_row = Array.new
    data.size.times do |j|
      new_row << data[i][j]
    end
    new_data << new_row
  end
  new_data
end

def kcluster(rows, distance = :pearson, k = 4)
  ranges = Array.new
  rows.first.size.times do |i|
    column = rows.map {|row| row[i]}
    ranges << [column.min, column.max]
  end
  
  clusters = Array.new
  k.times do |j|
    clusters[j] = Array.new
    rows.first.size.times do |i|
      clusters[j] << (rand * (ranges[i][1] = ranges[i][0]) + ranges[i][0])
    end
  end
  
  bestmatches, lastmatches = nil, nil
  
  99.times do |t|
    puts "Iteration #{t}"
    bestmatches = Array.new
    k.times {|i| bestmatches[i] = []}    
    
    rows.size.times do |j|
      row = rows[j]
      bestmatch = 0
      k.times do |i|
        d = method(distance).call(clusters[i], row)
        bd = method(distance).call(clusters[bestmatch], row)
        bestmatch = i 
      end
      bestmatches[bestmatch] << j
    end
    break if bestmatches==lastmatches
    lastmatches=bestmatches
    
    k.times do |i|
      avgs = [0.0] * rows.first.size
      if bestmatches[i].size > 0
        bestmatches[i].each do |rowid|
          rows[rowid].size.times do |m|
            avgs[m] += rows[rowid][m]
          end
        end
        avgs.size.times do |j|
          avgs[j] /= bestmatches[i].size
        end
        clusters[i] = avgs
      end
    end
  end
  bestmatches
end

def tanimoto(v1, v2)
  c1, c2, shr = 0, 0, 0
  
  v1.size.times do |i|
    c1 += 1 if v1[i] != 0
    c2 += 1 if v2[i] != 0
    shr += 1 if v1[i] != 0 && v2[i] != 0
  end
  1.0 - (shr.to_f / (c1 + c2 - shr))
end

def scaledown(data, rate = 0.01, distance = :pearson)
  n = data.size
  
  realdist = (0...n).map do |i|
    (0...n).map do |j|
      method(distance).call(data[i], data[j])
    end
  end
  
  outer_sum = 0.0
  
  # Randomly initialize the starting points of the locations in 2D
  loc = [[rand, rand]] * n
  fake_dist = [[0.0] * n] * n
  
  last_error = nil
  999.times do |m|
    # Find projected distances
    n.times do |i|
      n.times do |j|
        sum = (0..loc[i].size - 1).inject(0) do |memo, x|
          memo + (loc[i][x] - loc[j][x]) ** 2
        end
        fake_dist[i][j] = Math.sqrt(sum) if sum > 0
      end
    end
    
    # Move points
    grad = [[0.0, 0.0]] * n
    
    total_error = 0
    n.times do |k|
      n.times do |j|
        next if j == k
        # The error is percent difference between the distances
        error_term = (fake_dist[j][k] - realdist[j][k]) / realdist[j][k]
        
        # Each point needs to be moved away from or towards the other
        # piont in proportion to how much error it has
        grad[k][0] += ((loc[k][0] - loc[j][0]) / fake_dist[j][k]) * error_term
        grad[k][1] += ((loc[k][1] - loc[j][1]) / fake_dist[j][k]) * error_term
        
        # Keep track of the total error
        total_error += error_term.abs
      end
    end
    
    #puts total_error
    
    # If the answer got worse by moving the points, we are done
    break if last_error and last_error < total_error
    last_error = total_error
    
    # Move each of the points by learning rate times the gradient
    n.times do |k|
      loc[k][0] -= rate * grad[k][0]
      loc[k][1] -= rate * grad[k][1]
    end
  end
  
  return loc
  
end



require 'graph'
#blognames, words, data = readfile('blogdata1.txt')
# clusters = hcluster(data)
# #printclust(clusters, blognames)
# require 'graph'
# Graph.draw_dendogram(clusters, blognames, 'blogcluster.png')
# 
# rdata = rotate_matrix(data)
# wordclusters = hcluster(rdata)
# Graph.draw_dendogram(wordclusters, words, 'wordcluster.png')

#kclusters = kcluster(data, :pearson, 10)

# wants, people, data = readfile('zebo.txt')
# clust = hcluster(data, :tanimoto)
# Graph.draw_dendogram(clust, wants, 'zebo.png')

blognames, words, data = readfile('blogdata1.txt')
coords = scaledown(data)
Graph.draw2d(coords, blognames, 'blogs2d.png')