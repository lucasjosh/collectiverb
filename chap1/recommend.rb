#!/usr/bin/env ruby

REVIEWS = { 'Lisa Rose' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.5, 'Just My Luck' => 3.0, 'Superman Returns' => 3.5, 'You, Me and Dupree' => 2.5, 'The Night Listener' => 3.0},
            'Gene Seymour' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 3.5, 'Just My Luck' => 1.5, 'Superman Returns' => 5.0, 'The Night Listener' => 3.0, 'You, Me and Dupree' => 3.5},
            'Michael Phillips' => {'Lady in the Water' => 2.5, 'Snakes on a Plane' => 3.0, 'Superman Returns' => 3.5, 'The Night Listener' => 4.0},
            'Claudia Puig' => {'Snakes on a Plane' => 3.5, 'Just My Luck' => 3.0, 'The Night Listener' => 4.5, 'Superman Returns' => 4.0, 'You, Me and Dupree' => 2.5},
            'Nick LaSalle' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 'Just My Luck' => 2.0, 'Superman Returns' => 3.0, 'The Night Listener' => 3.0, 'You, Me and Dupree' => 2.0},
            'Jack Matthews' => {'Lady in the Water' => 3.0, 'Snakes on a Plane' => 4.0, 'The Night Listener' => 3.0, 'Superman Returns' => 5.0, 'You, Me and Dupree' => 3.5},
            'Toby' => {'Snakes on a Plane' => 4.5, 'You, Me and Dupree' => 1.0, 'Superman Returns' => 4.0}
}


def sim_distance(prefs, person1, person2)
  si = find_common_keys(prefs, person1, person2)
  return 0 if si.empty?
  
  sum_of_squares = 0
  
  prefs[person1].each do |k, item|
    if prefs[person2].key? k
      sum_of_squares += ((prefs[person1][k] - prefs[person2][k]) ** 2)
    end
  end
  
  1/(1 + sum_of_squares)
end

def sim_pearson(prefs, person1, person2)
  si = find_common_keys(prefs, person1, person2)
  n = si.size
  return 0 if n == 0
  
  # Find sum of each rating
  sum1 = si.keys.inject(0) {|sum1, j| sum1 + prefs[person1][j]}
  sum2 = si.keys.inject(0) {|sum2, j| sum2 + prefs[person2][j]}
  
  # Find sum of the ratings squared
  sum1_sq = si.keys.inject(0) {|sum1_sq, j| sum1_sq + prefs[person1][j] ** 2}
  sum2_sq = si.keys.inject(0) {|sum2_sq, j| sum2_sq + prefs[person2][j] ** 2}
  
  # Find sum of the products
  sum_prod = si.keys.inject(0) {|sum_prod, j| sum_prod + (prefs[person1][j] * prefs[person2][j])}
  
  num = sum_prod - (sum1 * sum2 / n)
  den = Math.sqrt( (sum1_sq - (sum1 ** 2) / n) * (sum2_sq - (sum2 ** 2) / n) )
  return 0 if den == 0
  
  return num / den
  
end

def top_matches(prefs, person, n = 5, similarity = :sim_pearson)
  scores = Array.new
  prefs.each do |k, value|
    if k != person
      scores << [method(similarity).call(prefs, person, k), k]
    end
  end
  scores.sort!.reverse![0...n]
end

def get_recommendations(prefs, person, similarity = :sim_pearson)
  totals = Hash.new(0)
  sim_sums = Hash.new(0)
  
  prefs.each do |k, value|
    if k != person
      sim = method(similarity).call(prefs, person, k)
      
      next if sim <= 0
      
      prefs[k].each do |name, value|
      
        if !prefs[person].key? name || prefs[person][name] == 0
          totals[name] += prefs[k][name] * sim
          sim_sums[name] += sim
        end
      end
    end
  end

  
  rankings = Array.new
  totals.each do |name, total|
    rankings << [(total / sim_sums[name]), name]
  end
  
  rankings.sort!.reverse!
end

def transform_hash(prefs)
  result = Hash.new
  prefs.each do |k, value|
    prefs[k].each do |item, value|
      result[item] = Hash.new unless result[item]
      result[item][k] = prefs[k][item]
    end
  end
  result
end

def calculate_similar_items(prefs, n = 10)
  result = Hash.new
  
  item_prefs = transform_hash(prefs)
  
  item_prefs.keys.each do |k|
    scores = top_matches(item_prefs, k, n, :sim_distance)
    result[k] = scores
  end
  result
end

def get_recommended_items(prefs, item_match, user)
  user_ratings = prefs[user]
  scores = Hash.new
  total_sim = Hash.new
  
  user_ratings.each do |item, rating|
    item_match[item].each do |similarity, item2|
      next if user_ratings.key? item2
      
      scores[item2] = 0 unless scores[item2]
      scores[item2] += similarity * rating
      
      total_sim[item2] = 0 unless total_sim[item2]
      total_sim[item2] += similarity.to_f
    end
  end
  
  rankings = Array.new
  scores.each do |item, score|
    rankings << [(score / total_sim[item]), item]
  end
  
  rankings.sort!.reverse!
end

def find_common_keys(hsh, str_1, str_2)
  si = Hash.new
  hsh[str_1].each do |k, item|
    si[k] = 1 if hsh[str_2].key? k
  end
  si
end

puts sim_distance(REVIEWS, 'Lisa Rose', 'Nick LaSalle')

puts sim_pearson(REVIEWS, 'Lisa Rose', 'Gene Seymour')

puts top_matches(REVIEWS, 'Toby', 3)

puts get_recommendations(REVIEWS, 'Toby')

movies = transform_hash(REVIEWS)
puts get_recommendations(movies, 'Just My Luck')

item_sim = calculate_similar_items(REVIEWS)
puts get_recommended_items(REVIEWS, item_sim, 'Toby')