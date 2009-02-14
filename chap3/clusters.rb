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


blognames, words, data = readfile('blogdata1.txt')
clusters = hcluster(data)
printclust(clusters, blognames)

