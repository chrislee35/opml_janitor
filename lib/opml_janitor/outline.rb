module OpmlJanitor
  
  class Outline
    
    attr_reader :hash
    
    def initialize(node)
      @node = node
      @hash = {}
    end
    
    def to_hash
      @node.attributes.each do |attribute|
        key = underscore(attribute[0]).to_sym
        @hash[key] = @node.attr(attribute[0])
      end
      @hash
    end
    
    private 
    
    # from ActiveSupport
    def underscore(camel_cased_word)
      word = camel_cased_word.to_s.dup
      word.gsub!(/::/, '/')
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
    
  end
  
end