require "json"

def lp_traverse(s, path = [])
  return if s.nil?
  ret = []
  key = s.dig("asn_statementLabel", "literal")
  val = s.dig("asn_statementNotation", "literal") || s.dig("dcterms_title", "literal")  || s["Id"]
  newpath = path + [{key.to_sym => val}]
  if s.dig("asn_statementLabel", "literal") == "Content description"
    scot = Hash2Array(s.dig("asn_conceptTerm"))&.map { |t| t["prefLabel"] } || []
    kw = Hash2Array(s.dig("asn_conceptKeyword"))&.map { |t| t["literal"] } || []
    code = s.dig("asn_statementNotation", "literal")
    lvl = s.dig("dcterms_educationLevel", "prefLabel")
    text2 = ""
    s["children"]&.each do |s1|
      text2 += " --- " + s1["text"]
    end
    ret = {code: code, level: lvl, id: s["Id"], text: s["text"], elab: text2, path: newpath, keywords: scot + kw}
  end

  s["children"]&.each do |s1|
    r = lp_traverse(s1, newpath) and !r.empty? and ret << r
  end
  ret
end

def Hash2Array(h)
  return [h] if h.is_a? Hash
  h
end

lp = JSON.parse(File.read(ARGV[0], encoding: "utf-8"))
ret = []
lp.each { |l| ret << lp_traverse(l) }
puts JSON.pretty_generate(ret.flatten)
