module Representations
  #Enables automatic wrapping
  #Currently there's no way of deactivating it
  def self.enable_automatic_wrapping=(value)
    if value
      ActionView::Base.class_eval do 
       def instance_variable_set_with_r(symbol, obj)
         load ActiveSupport::Dependencies.search_for_file('representations.rb')
         obj = Representations.representation_for(obj, self, symbol.to_s[1..-1]) if obj.is_a?(ActiveRecord::Base)
         instance_variable_set_without_r(symbol, obj) #call to the original method
       end
       self.alias_method_chain :instance_variable_set, :r
     end
    end
  end
  #Creates Representation for object passed as a paremeter, type of the representation
  #depends on the type of the object
  def representation_for(object, template, name=nil, parent=nil)
    representation_class =
      begin
        if object.is_a?(ActiveRecord::Base)
          ActiveRecordRepresentation
        else
          "Representations::#{object.class.to_s.demodulize}Representation".constantize 
        end
      rescue 
        AssociationsRepresentation if object.ancestors.include?(ActiveRecord::Associations) rescue DefaultRepresentation
      end
    representation_class.new(object, template, name, parent)
  end

  module_function :representation_for
  class Representation 

    #value - object for which the representation is created 
    #template - template view (needed because some ActionView::Base methods are private)
    #name - the actuall name of the method that was called on the object's parent that is being initialize
    #parent - Representation object which contains the object that is being initialize
    def initialize(value, template, name=nil, parent=nil)
      @value = value
      @name = name
      @template = template
      @parent = parent
      #extend class if user provided appropriate file (look at the files app/representations/*_representation.rb)
      self.send(:extend, "::#{self.class.to_s.demodulize}".constantize) rescue Rails.logger.info "No AR extension defined for #{self.class.to_s}"
      #extend this object's class if user provided per-model extensions (i.e. for Job model look at app/representations/JobRepresentation.rb)
      self.send(:extend, "::#{value.class.to_s}Representation".constantize) rescue Rails.logger.info "No per-model extension defined for #{value.class.to_s}"

    end
    def +(arg)
      to_s + arg.to_s
    end
    def id
      @value
    end
    #returns escaped string from the object's to_s method
    def to_s
      ERB::Util::h(@value.to_s)
    end
    #returns html label tag for the representation
    def label(value = nil, html_options = {})
      tree = get_parents_tree
      for_attr_value = tree.collect{ |x| x[0] }.join('_')
      tags = get_tags(html_options, {:for => for_attr_value})
      value = ERB::Util::h(@name.humanize) if value.nil?
      %Q{<label #{tags}>#{value}</label>}
    end
    protected
    #Call the passed block (if any) 
    def with_block(&block)
      yield self if block_given?
    end
    #Returns two dimensional array based on the tree of the Represantation objects which are linked together by the @parent field
    #First element of the array consists of Representation's @name and the second of Representation's class
    def get_parents_tree
      tree = Array.new
      tree[0] = []
      tree[0][0] = @name
      tree[0][1] = self.class
      parent = @parent
      while parent do #iterate parent tree
        array = []
        array[0] = parent.instance_variable_get(:@name)
        array[1] = parent.class
        tree.unshift(array)
        parent = parent.instance_variable_get(:@parent)
      end
      tree #tree now looks something like this [['user', ActiverRecordRepresentation], ['nick', DefaultRepresentation]]
    end
    #Creates value of the html name attribute according to the passed tree 
    def get_html_name_attribute_value(tree)
      first = tree.delete_at(0)
      root_name = first[0]
      name = []
      prev = nil
      tree.each do |elem| 
        if elem[1] == DefaultRepresentation || elem[1] == TimeWithZoneRepresentation || prev == AssociationsRepresentation
          name.push "[" + elem[0] + "]"
        else
          name.push "[" + elem[0] + "_attributes]"
        end
        prev = elem[1]
      end
      name.unshift(root_name)
    end
    #Returns string created by merging two hashes of html options passed as the arguments
    def get_tags(user_options, base_options)
      options = base_options.merge(user_options)
      options.stringify_keys!
      options = options.sort
      options.map{ |key, value| %(#{key}="#{value}" ) }
    end
  end

  class DefaultRepresentation < Representation
    #not tested in the view
    #Returns string with html check box tag
    def check_box(checked_value = "1", unchecked_value = "0", html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      name_attr_value = get_html_name_attribute_value(tree)
      tags = get_tags(html_options, {:value => checked_value, :id => id_attr_value, :name=>name_attr_value})
      %Q{<input type="checkbox" #{tags}/>\n<input type="hidden" value="#{unchecked_value}" id="#{id_attr_value}" name="#{name_attr_value}"/>}
    end
    #not tested in the view
    #Returns string with html file field tag
    def file_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="file" #{tags}/>}
    end
    #not tested in the view
    #Returns string with html hidden input tag
    def hidden_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="hidden" #{tags}/>}
    end
    #Returns string with html text input tag
    def text_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="text" #{tags}/>}
    end
    #Returns string with html text area tag
    def text_area(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      tags = get_tags(html_options, {:id => id_attr_value, :name => get_html_name_attribute_value(tree)})
      %Q{<textarea #{tags}>\n#{to_s}\n</textarea>}
    end
    #Returns string with html password tag
    def password_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="password" #{tags}/>}
    end
    #Returns string with html radio button tag
    def radio_button(value, html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.collect{ |x| x[0] }.join('_') + "_#{value}"
      name_attr_value = get_html_name_attribute_value(tree)
      tags = get_tags(html_options, {:name => name_attr_value, :value=>value, :id=>id_attr_value, :checked=>"#{@value.capitalize==value.capitalize}"})
      %Q{<input type="radio" #{tags}/>}
    end
    #Returns string with html label tag with for attribute set to the radio button of this object
    def radio_button_label(radio_button_value, value = nil, html_options = {})
      tree = get_parents_tree
      for_attr_value = tree.collect{ |x| x[0] }.join('_') + "_#{radio_button_value}"
      value = radio_button_value.capitalize if value.nil?
      tags = get_tags(html_options, {:for => for_attr_value})
      %Q{<label #{tags}>#{ERB::Util::h(value)}</label>}
      end
  end
  #Representation for objects which are nil
  class NilClassRepresentation < Representation
    #Returns self so the calls:
    #nil_object.not_defined_method.another_not_defined_method
    #want raise an error
    def method_missing(method_name, *args)
      return self
    end
    #Passed block shouldn't be called
    def with_block(&block)
    end
    #Returns blank string
    def to_s
      return ''
    end
  end
  #Representation for ActiveRecord::Base object's
  class ActiveRecordRepresentation < Representation
    #Render partial with the given name and given namespace as a parameter
    def partial(partial_name, namespace = nil)
      unless namespace
        namespace = @template.controller.class.parent_name.split('::') rescue []
        namespace = namespace.join('/') 
      end
      namespace += '/'
      path = @value.class.to_s.pluralize
      path = namespace + path
      path.downcase!
      @template.render(:partial => "#{path}/#{partial_name}")
    end
    #Render partial if it has 'has_one' associtation with the other model, otherwise do normal to_s
    #TODO make this method namespace awareness
    def to_s
      #@parent.instance_variable_get(:@value).class.reflections[:"#{@name}"].macro == :has_one ? @template.render(:partial => "#{@value.class.to_s.downcase.pluralize}/#{@value.class.to_s.downcase}") : super
      if @parent && @parent.instance_variable_get(:@value).class.reflections[:"#{@name}"].macro == :has_one 
        partial(@value.class.to_s.downcase) 
      else
        super
      end
    end
    #Form builder
    def form(&block)
      raise "You need to provide block to form representation" unless block_given?
      content = @template.capture(self, &block)
      @template.concat(@template.form_tag(@value))
      @template.concat(content)
      @template.concat("</form>")
      self
    end
    #Forwards ActiveRecord invocation and wraps result in appropriate Representation
    #Suppose that User extends ActiveRecord::Base :
    #ar_user = User.new
    #ar_user.nick = 'foo'
    #user = r(ar_user) #user is now ActiveRecordRepresentation
    #user.nick.text_field #method_missing will be called on user with method_name = 'nick' in which new method for user will be created and will be called. The newly created method will create a new DefaultRepresentation with @value set to the string 'foo'. Next the text_field will be called on the newly created DefaultRepresentation
    def method_missing(method_name, *args, &block)
      method = <<-EOF
            def #{method_name}(*args, &block)
              @__#{method_name} ||= Representations.representation_for(@value.#{method_name}, @template, "#{method_name}", self)
              @__#{method_name}.with_block(&block)
              @__#{method_name} if block.nil?
            end
      EOF
      ::Representations::ActiveRecordRepresentation.class_eval(method, __FILE__, __LINE__)
      self.__send__(method_name, &block)
    end
  end
  #Representation for TimeWithZone object 
  class TimeWithZoneRepresentation < Representation
    def select(passed_options = {}, html_options = {})
      options = {:defaults => {:day => @value.day, :month => @value.month, :year => @value.year}}
      options.merge!(passed_options)
      tree = get_parents_tree
      name = get_html_name_attribute_value(tree)
      @template.date_select(name, @name, options, html_options)
    end
  end
  #Representation for Collections
  class AssociationsRepresentation < Representation
    #initilize @num variable
    def initialize(object, template, name, parent)
      super
      @num = 0
    end
    #Creates Representation for every object in the Array and invokes passed block with this Representation as the argument
    def each
      @value.each do |object|
        representation_object = Representations.representation_for(object, @template, object.id.to_s, self)
        yield representation_object
      end
    end
    #Creates new object in the collection and input fields for it defined in the passed block 
    def build
      new_object = @value.build 
      representation_object = AssociationsRepresentation::NewRecordRepresentation.new(new_object, @template, 'new_' + num.to_s, self)
      yield representation_object
    end
    private 
    attr_reader :num
    #Used for generating unique @name for ArrayRepresentation::NewRecordRepresentation
    def num
      @num += 1 
    end
    #Representation that wraps newly created ActiveRecord::Base that will be added to some collection
    class NewRecordRepresentation < Representation
      #Creates new method which wraps call for ActionRecord
      #New method returns Representation which represents datatype in the appropriate column
      def method_missing(method_name_symbol, *args, &block)
        method_name = method_name_symbol.to_s
        representation_class = case @value.class.columns_hash[method_name].type
                               when :string
                                 "DefaultRepresentation"
                               when :date
                                 "TimeWithZoneRepresentation"
                               end
        method = <<-EOF
          def #{method_name}(*args, &block)
             @__#{method_name} ||= #{representation_class}.new(@value.#{method_name}, @template, "#{method_name}", self)
             @__#{method_name}.with_block(&block)
             @__#{method_name} if block.nil?
          end
        EOF
        ::Representations::AssociationsRepresentation::NewRecordRepresentation.class_eval(method, __FILE__, __LINE__)
        self.__send__(method_name_symbol, &block)
      end
    end
  end
end
