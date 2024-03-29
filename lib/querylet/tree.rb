module Querylet
  class Tree < Parslet::Transform
    class TreeItem < Struct
      def eval(context)
        _eval(context)
      end
    end

    class TemplateContent < TreeItem.new(:content)
      def _eval(context)
        return content
      end
    end

    class Variable < TreeItem.new(:item)
      def _eval(context)
        context.get(item)
      end
    end

    class String < TreeItem.new(:content)
      def _eval(context)
        return content
      end
    end

    class Parameter < TreeItem.new(:name)
      def _eval(context)
        if name.is_a?(Parslet::Slice)
          context.get(name.to_s)
        else
          name._eval(context)
        end
      end
    end

    class Partial < TreeItem.new(:partial, :path, :parameters)
      def _eval(context)
        data = {}
        [parameters].flatten.map(&:values).map do |vals|
          # we have to set it as sym so it overrides correctly
          data[vals.first.to_sym] = vals.last._eval(context)
        end
        content = context.get_partial(partial.to_s, path, data)
        if partial == 'array'
        <<-HEREDOC.chomp
(SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
#{content}
) array_row)
        HEREDOC
        elsif partial == 'object'
        <<-HEREDOC.chomp
(SELECT COALESCE(row_to_json(object_row),'{}'::json) FROM (
#{content}
) object_row)
      HEREDOC
        elsif partial == 'include'
          content
        end
      end
    end

    class IfBlock < TreeItem.new(:if_kind, :variable, :items)
      def _eval(context)
        if if_kind == 'if'
          if context.get(variable)
            items.map {|item| item._eval(context)}.join()
          end
        elsif if_kind == 'unless'
          unless context.get(variable)
            items.map {|item| item._eval(context)}.join()
          end
        end
      end
    end

    class IfElseBlock < TreeItem.new(:if_kind, :variable, :items, :else_items)
      def _eval(context)
        if if_kind == 'if'
          if context.get(variable)
            items.map {|item| item._eval(context)}.join()
          else
            else_items.items.map {|item| item._eval(context)}.join()
          end
        elsif if_kind == 'unless'
          unless context.get(variable)
            items.map {|item| item._eval(context)}.join()
          else
            else_items.items.map {|item| item._eval(context)}.join()
          end
        end
      end
    end

    class Filter < TreeItem.new(:filter,:parameter)
      def _eval(context)
        val = context.get(parameter.item)
        if filter == 'int'
          if val.is_a?(Integer)
            val.to_s
          else
            raise "expected input for: #{parameter.item} to be an Integer"
          end
        elsif filter == 'float'
          if val.is_a?(Float)
            val.to_s
          else
            raise "expected input for: #{parameter.item} to be a Float"
          end
        elsif filter == 'arr'
          if val.is_a?(Array)
            if val.all?{|a| a.class.to_s == 'String' } # to_a? was not working
              "'#{val.join("','")}'"
            elsif val.all?{|a| a.is_a?(Integer) }
              val.join(',')
            elsif val.all?{|a| a.is_a?(Float) }
              val.join(',')
            else
              raise "expected input for: #{parameter.item} to be an Array with all of the same datatype eg String, Integer, Float"
            end
          else
            raise "expected input for: #{parameter.item} to be an Array"
          end
        elsif filter == 'str'
          if val.class.to_s == 'String' # to_a? was not working
            "'#{val}'"
          else
            raise "expected input for: #{parameter.item} to be a String"
          end
        elsif filter == 'wild'
          if val.class.to_s == 'String' || val.is_a?(Integer) || val.is_a?(Float)
            "'%#{val}%'"
          else
            raise "expected input for: #{parameter.item} to be String, Integer or Array"
          end
        else
          raise "unexpected filter name: #{filter}"
        end
      end
    end

    class Block < TreeItem.new(:block,:items)
      def _eval(context)
        content = items.map {|item| item._eval(context)}.join()
        if block == 'array'
        <<-HEREDOC.chomp
(SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
#{content}
) array_row)
      HEREDOC
        elsif block == 'object'
        <<-HEREDOC.chomp
(SELECT COALESCE(row_to_json(object_row),'{}'::json) FROM (
#{content}
) object_row)
      HEREDOC
        else
          content
        end
      end
    end

    class Items < TreeItem.new(:items)
      def _eval(context)
        items.map {|item| item._eval(context)}.join()
      end
      alias :fn :_eval

      def add_item(i)
        items << i
      end
    end

  end
end
