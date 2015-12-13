require 'emfrp/syntax'

module Emfrp
  class FuncCall
    def codegen(ct, stmts)
      name = ct.func_name(self[:name][:desc], self[:typing], self[:args].map{|x| x[:typing]})
      "#{name}(#{self[:args].map{|x| x.codegen(ct, stmts)}})"
    end
  end

  class ValueConst
    def codegen(ct, stmts)
      name = ct.constructor_name(self[:name][:desc], self[:typing])
      "#{name}(#{self[:args].map{|x| x.codegen(ct, stmts)}})"
    end
  end

  class LiteralIntegral
    def codegen(ct, stmts)
      self[:entity][:desc]
    end
  end

  class LitaralChar
    def codegen(ct, stmts)
      self[:entity][:desc]
    end
  end

  class VarRef
    def codegen(ct, stmts)
      ct.escape_name(self[:name][:desc])
    end
  end

  class MatchExp
    def codegen(ct, stmts)
      name = "_tmp%03d" % ct.uniq_id_gen
      stmts << "#{ct.tref(self)} #{name}"
      left = self[:exp]
      if left.is_a?(VarRef)
        left_vname = left[:name][:desc]
      else
        left_vname = "_tmp%03d" % ct.uniq_id_gen
        stmts.unshift "#{ct.tref(left)} #{left_vname};"
        stmts.push "#{left_vname} = #{left.codegen(ct, stmts)};"
      end
      self[:cases].each_with_index do |c, i|
        then_stmts = []
        cond_exps = pattern_to_cond_exps(ct, left_vname, then_stmts, c[:pattern])
        cond_exp = cond_exps.size == 0 ? "1" : cond_exps.join(" && ")
        if c[:exp].is_a?(SkipExp)
          then_stmts << "return 0;"
        else
          then_stmts << "#{vname} = #{c[:exp].codegen(ct, then_stmts)};"
        end
        if i == 0
          stmts << ct.make_block("if (#{cond_exp}) {", then_stmts, "}")
        else
          stmts << ct.make_block("else if (#{cond_exp}) {", then_stmts, "}")
        end
      end
      return name
    end

    def pattern_to_cond_exps(ct, receiver, stmts, pattern)
      if pattern[:ref]
        stmts << "#{ct.tref(pattern)} #{pattern[:ref][:desc]} = #{receiver};"
      end
      case pattern
      when ValuePattern
        conds = []
        type_def = ct.tdef(pattern)
        accessor = type_def[:static] ? "." : "->"
        if type_def[:tvalues].size > 1
          tvalue_id = type_def[:tvalues].index{|x| x[:name] == pattern[:name]}
          if type_def[:cstruct_name]
            conds << "#{receiver}" + accessor + "tvalue_type == " + tvalue_id.to_s
          else
            conds << "#{receiver} == #{tvalue_id}"
          end
        end
        new_receiver = "#{receiver}" + accessor + "value." + pattern[:name][:desc]
        pattern[:args].each_with_index do |x, i|
          conds += pattern_to_cond_exps(ct, new_receiver + ".member#{i}", stmts, x)
        end
        return conds
      when IntegralPattern
        return ["#{receiver} == #{pattern[:val][:entity][:desc]}"]
      else
        return []
      end
    end
  end
end
