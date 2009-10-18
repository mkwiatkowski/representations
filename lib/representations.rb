module Representations
  #Creates Representation for object passed as a paremeter, type of the representation
  #depends on the type of the object
  def representation_for(object, template, name=nil, parent=nil)
    representation_class = if object.is_a?(ActiveRecord::Base)
      ActiveRecordRepresentation
    else
      "Representations::#{object.class.to_s.demodulize}Representation".constantize rescue DefaultRepresentation
    end
    representation_class.new(object, template, name, parent)
  end

  module_function :representation_for

  class Representation 

    #value - object for which the representation is created 
    #template - template view
    #name - the actuall name of the method that was called on the object's parent that is being initialize
    def initialize(value, template, name=nil, parent=nil)
      @value = value
      @name = name
      @template = template
      @parent = parent
    end

    def id
      @value
    end
    #returns escaped string from the object's to_s method
    def to_s
      ERB::Util::h(@value.to_s)
    end
    #returns html label tag for the representation
    def label(value, html_options = {})
      tree = get_parents_tree
      for_attr_value = tree.join('_')
      tags = get_tags(html_options, {:for => for_attr_value})
      value = ERB::Util::h(@name.humanize) if value.nil?
      %Q{<label #{tags}>#{value}</label>}
    end

    protected
    #Call the passed block (if any) 
    def with_block(&block)
      yield self if block_given?
    end
    #Returns array of Represantation objects which are linked together by @parent field
    def get_parents_tree
      children_names = Array.new
      parent = @parent
      children_names.push(@name)
      while parent.nil? == false do #iterate parent tree
        children_names.push(parent.instance_variable_get(:@name))
        parent = parent.instance_variable_get(:@parent)
      end #children_names now looks something like that [name, profile, user]
      children_names.reverse
    end
    #Creates value of the html name attribute according to passed tree of objects
    def get_html_name_attribute_value(tree)
      root_name = tree.delete_at(0)
      name = Array.new
      tree.each_index do |idx| 
        name[idx] =  if idx < tree.length - 1
             "[" + tree[idx] + "_attributes]"
                     else
             "[" + tree[idx] + "]"
                     end
      end
      name.unshift(root_name)
    end
    #Returns string created by merging two hashes of html options passed as an argument
    def get_tags(user_options, base_options)
      base_options.merge!(user_options)
      base_options.stringify_keys!
      base_options.map{ |key, value| %(#{key}="#{value}" ) }
    end
  end

  class DefaultRepresentation < Representation

    #not tested in the view
    #Returns string with html check box tag
    def check_box(checked_value = "1", unchecked_value = "0", html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      name_attr_value = get_html_name_attribute_value(tree)
      tags = get_tags(html_options, {:value => checked_value, :id => id_attr_value, :name=>name_attr_value})
      %Q{<input type="checkbox" #{tags}/>\n<input type="hidden" value="#{unchecked_value}" id="#{id_attr_value}" name="#{name_attr_value}"/>}
    end
    #not tested in the view
    #Returns string with html file field tag
    def file_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="file" #{tags}/>}
    end
    #not tested in the view
    #Returns string with html hidden input tag
    def hidden_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="hidden" #{tags}/>}
    end
    #Returns string with html text input tag
    def text_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="text" #{tags}/>}
    end
    #Returns string with html text area tag
    def text_area(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      tags = get_tags(html_options, {:id => id_attr_value, :name => get_html_name_attribute_value(tree)})
      %Q{<textarea #{tags}>\n#{to_s}\n</textarea>}
    end
    #Returns string with html password tag
    def password_field(html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') 
      tags = get_tags(html_options, {:value => to_s, :id => id_attr_value, :name=>get_html_name_attribute_value(tree)})
      %Q{<input type="password" #{tags}/>}
    end
    #Returns string with html radio button tag
    def radio_button(value, html_options = {})
      tree = get_parents_tree
      id_attr_value = tree.join('_') + "_#{value}"
      name_attr_value = get_html_name_attribute_value(tree)
      tags = get_tags(html_options, {:name => name_attr_value, :value=>value, :id=>id_attr_value, :checked=>"#{@value.capitalize==value.capitalize}"})
      %Q{<input type="radio" #{tags}/>}
    end
    #Returns string with html label tag with for attribute set to the radio button of this object
    def radio_button_label(radio_button_value, value = nil, html_options = {})
      tree = get_parents_tree
      for_attr_value = tree.join('_') + "_#{radio_button_value}"
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
      #Form builder
      def form(&block)
        raise "You need to provide block to form representation" unless block_given?
        content = @template.capture(self, &block)
        @template.concat(@template.form_tag(@value))
        @template.concat(content)
        @template.concat("</form>")
        self
      end
      #Forwards ActiveRecord invocation and wraps result in apropriate Representation
      #Suppose that User extends ActiveRecord::Base :
      #ar_user = User.new
      #ar_user.nick = 'foo'
      #user = r(ar_user) #user is now ActiveRecordRepresentation
      #user.nick.text_field #method_missing will be called on user with method_name = 'nick' in which new method for user will be created and will be called. The newly created method will create a new DefaultRepresentation with @value set to the string 'foo'. Next the text_field will be called on the newly created DefauleRepresentation
      #
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
        tree.pop
        name = get_html_name_attribute_value(tree)
        @template.date_select(name, @name, options, html_options)
      end
    end
  end