#require 'representations'
module Representations
  #Representation for ActiveRecord::Base objects
  class ActiveRecordRepresentation < Representation
    #Render partial with the given name and given namespace as a parameter
    def partial(partial_name, namespace = nil)
      namespace = get_namespace unless namespace
      namespace += '/'
      path = @name.pluralize
      path = namespace + path
      path.downcase!
      @template.render(:partial => "#{path}/#{partial_name}")
    end
    #Render partial if it has 'has_one' associtation with the other model, otherwise do normal to_s
    def to_s
      @parent && @parent.instance_variable_get(:@value).class.reflections[:"#{@name}"].macro == :has_one ? partial(@name) : super
    end
    #Form builder
    def form(&block)
      raise "You need to provide block to form representation" unless block_given?
      namespace = get_namespace
      namespace = '/' + namespace unless namespace.blank?
      path = namespace + '/' + @name.pluralize
      path.downcase!
      r_for_form = ActiveRecordForFormRepresentation.new(@value, @template, @name, @parent)
      content = @template.capture(r_for_form, &block)
      @template.concat(@template.form_tag(path))
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
    private
    #Gets path to namespace (i.e. if controller is Good::Bad::Ugly::UsersController the R is in the namespace good/bad/ugly)
    def get_namespace
        namespace = @template.controller.class.parent_name.split('::') rescue []
        namespace = namespace.join('/') 
    end
    private
    #Wraps ActiveRecord::Base objects in the forms. This object will not create NilClassR for nil objects 
    #instead it will wrap in R depending on the datatype in the table
    class ActiveRecordForFormRepresentation < ActiveRecordRepresentation
      #Creates Representation for object passed as a paremeter, type of the representation
      #depends on the type of the object
      #It differs from Representations.representation_for that it will not wrap NilClass objects in the NilClassRepresentations, instead
      #it will wrap it in R depending on the datatype in the table
      def self.representation_for(object, template, name, parent=nil)
        representation_class = 
        begin
          if object.is_a?(ActiveRecord::Base)
            ActiveRecordRepresentation::ActiveRecordForFormRepresentation
          else
            "Representations::#{object.class.to_s.demodulize}Representation".constantize 
          end
        rescue 
          AssociationsRepresentation if object.ancestors.include?(ActiveRecord::Associations) rescue DefaultRepresentation
        end
        #if wrapping object is nil do NOT wrap it in the NilClassRepresentation
        if representation_class == NilClassRepresentation 
          representation_class = case parent.instance_variable_get(:@value).class.columns_hash[name].type
                                 when :string
                                   DefaultRepresentation
                                 when :date
                                   TimeWithZoneRepresentation
                                 end
        end
        representation_class.new(object, template, name, parent)
      end
      #TODO merge self.representation_for with this method
      def method_missing(method_name, *args, &block)
        method = <<-EOF
            def #{method_name}(*args, &block)
              @__#{method_name} ||= Representations::ActiveRecordRepresentation::ActiveRecordForFormRepresentation.representation_for(@value.#{method_name}, @template, "#{method_name}", self)
              @__#{method_name}.with_block(&block)
              @__#{method_name} if block.nil?
            end
        EOF
        ::Representations::ActiveRecordRepresentation::ActiveRecordForFormRepresentation.class_eval(method, __FILE__, __LINE__)
        self.__send__(method_name, &block)
      end
    end
  end
end
