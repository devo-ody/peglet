---
--- Generated by Luanalysis
--- Created by rodelbianco.
--- DateTime: 4/1/23 1:10 PM
---

local compiler = { _version = "0.0.1" }

local helpers = require('./utils/helpers')

local blocks = {}
local current_block = 1

function variable_as_num(state, id, should_check_local)
    should_check_local = false
    variable_name = helpers.deepcopy(id):gsub("@", "")
    local function_definition = state.functions[variable_name]
    if function_definition then
        error('Compilation Error: [' .. variable_name .. '] is a function')
    end
    local num = state.vars[variable_name]
    if not num then
        num = state.num_of_vars + 1
        state.num_of_vars = num
        state.vars[variable_name] = num
    elseif should_check_local then
        print('block ('..current_block..') -> '..helpers.as_string(blocks[current_block]))

        if blocks[current_block] and blocks[current_block][variable_name] then
            error('Compilation Error: variable [' .. variable_name .. '] already defined')
        else
            blocks[current_block] = blocks[current_block] or {}
            blocks[current_block][variable_name] = true
        end
    end

    return num
end

function bool_as_num(value)
    if value then
        return 1
    else
        return 0
    end
end

function pushCode(state, op)
    local exec_plan = state.exec_plan
    exec_plan[#exec_plan + 1] = op
end

function get_exec_plan_position(state)
    return #state.exec_plan
end

function generate_error(state, ast)
    error('Compilation Error (ERR-' .. ast.id .. '): ' .. ast.msg .. '')
end

function generate_unconditional_jump(state)
    pushCode(state, 'jump')
    pushCode(state, 0)
    return get_exec_plan_position(state)
end

function generate_conditional_jump_false(state)
    pushCode(state, 'jumpz')
    pushCode(state, 0)
    return get_exec_plan_position(state)
end

function generate_conditional_jump_true(state)
    pushCode(state, 'jumpo')
    pushCode(state, 0)
    return get_exec_plan_position(state)
end

function generate_conditional_jump_false_and_pop(state)
    pushCode(state, 'jumpzp')
    pushCode(state, 0)
    return get_exec_plan_position(state)
end

function generate_conditional_jump_false_or_pop(state)
    pushCode(state, 'jumpnzp')
    pushCode(state, 0)
    return get_exec_plan_position(state)
end

function fix_jump_current_position(state, jump_position)
    state.exec_plan[jump_position] = get_exec_plan_position(state) - jump_position
end

function generate_jump_label(state, label_position)
    pushCode(state, 'jump')
    pushCode(state, label_position - get_exec_plan_position(state) - 1)
end

function generate_function_definition(state, ast)
    local function_state = state.functions[ast.name]
    if function_state and not function_state.forward then
        error('Compilation Error: function ' .. ast.name .. ' already defined')
    end

    function_state = function_state or { functions = state.functions, exec_plan = {},
                                         vars = helpers.deepcopy(state.vars), num_of_vars = helpers.deepcopy(state.num_of_vars),
                                         params = helpers.deepcopy(ast.params), forward = nil }

    if ast.function_block then
        function_state.forward = nil
        current_block = current_block + 1
        generate_statement(function_state, ast.function_block)
        pushCode(function_state, 'push')
        pushCode(function_state, 0)
        pushCode(function_state, 'ret')
    else
        function_state.forward = get_exec_plan_position(state)
    end

    state.functions[ast.name] = function_state

    return function_state
end

function generate_function_call(state, ast)
    local function_definition = state.functions[ast.name]
    if not function_definition then
        error('Compilation Error: function [' .. ast.name .. '] not found')
    end

    local args = ast.args
    if #function_definition.params ~= #args then
        local last_param = function_definition.params[#function_definition.params]

        if #function_definition.params - #args == 1 and #last_param == 3 then
            print('last param -> ('..#last_param..' params) '..helpers.as_string(last_param))
            print(helpers.as_string(function_definition.vars))
            args[#args+1] = last_param[3]
        else
            error('Compilation Error: Calling [' .. ast.name ..
                    '(' .. helpers.as_string(#function_definition.params) .. ' params)] with wrong number of arguments [' ..
                    helpers.as_string(#ast.args) .. ' argument]')
        end
    end

    pushCode(state, 'call')
    if #args > 0 then
        pushCode(state, 'args')
        pushCode(state, #args)
        for i = 1, #args do
            generate_expression(state, args[i])
            pushCode(state, 'inject')
            local param_name = function_definition.params[i]
            if helpers.istable(param_name) then
                param_name = function_definition.params[i][1]
            end
            pushCode(state, variable_as_num(function_definition, param_name, true))
        end
    end
    pushCode(state, function_definition.exec_plan)
end

function generate_expression(state, ast)
    if ast.tag == 'empty' then
    elseif ast.tag == 'default' then
        pushCode(state, 'pushdef')
    elseif ast.tag == 'number' then
        pushCode(state, 'push')
        pushCode(state, ast.value)
    elseif ast.tag == 'boolean' then
        pushCode(state, 'push')
        pushCode(state, bool_as_num(ast.value))
    elseif ast.tag == 'variable' then
        if string.match(ast.id, "@") then
            pushCode(state, 'global_load')
        else
            pushCode(state, 'load')
        end
        pushCode(state, variable_as_num(state, ast.id))
    elseif ast.tag == 'binop' then
        generate_expression(state, ast.exp1)
        generate_expression(state, ast.exp2)
        pushCode(state, ast.op)
    elseif ast.tag == 'indexed_var' then
        generate_expression(state, ast.array)
        generate_expression(state, ast.index)
        pushCode(state, 'getarray')
    elseif ast.tag == 'new_arr' then
        generate_expression(state, ast.seed_expression)
        generate_expression(state, ast.size)
        pushCode(state, 'newarray')
    elseif ast.tag == 'function_call' then
        generate_function_call(state, ast)
    elseif ast.tag == 'logic' then
        if ast.op == 'and' then
            generate_expression(state, ast.exp1)
            local jump_position = generate_conditional_jump_false_and_pop(state)
            generate_expression(state, ast.exp2)
            fix_jump_current_position(state, jump_position)
        else
            generate_expression(state, ast.exp1)
            local jump_position = generate_conditional_jump_false_or_pop(state)
            generate_expression(state, ast.exp2)
            fix_jump_current_position(state, jump_position)
        end
    elseif ast.tag == 'comp' then
        generate_expression(state, ast.exp1)
        generate_expression(state, ast.exp2)
        pushCode(state, ast.op)
    elseif ast.tag == 'unary' then
        generate_expression(state, ast.exp1)
        pushCode(state, ast.op)
    elseif ast.tag == 'boolean_neg' then
        generate_expression(state, ast.exp1)
        pushCode(state, ast.op)
    elseif ast.is_error then
        generate_error(state, ast)
    else
        error('Compilation Error: invalid expression tag (' .. helpers.as_string(ast.tag) .. ') tree -> (\n' .. helpers.as_string(ast) .. '\n)')
    end
end

function generate_assignment(state, ast)
    local variable = ast.variable
    if variable.tag == 'variable' then
        generate_expression(state, ast.expression)

        local should_check_local = false
        if string.match(variable.id, "@") then
            pushCode(state, 'global_store')
        elseif variable.variant == 'local' then
            should_check_local = true
            pushCode(state, 'local_store')
        else
            pushCode(state, 'store')
        end
        pushCode(state, variable_as_num(state, variable.id, should_check_local))
    elseif variable.tag == 'indexed_var' then
        generate_expression(state, variable.array)
        generate_expression(state, variable.index)
        generate_expression(state, ast.expression)
        pushCode(state, 'setarray')
    else
        error('Compilation Error: invalid expression. tag:(' .. helpers.as_string(ast.variable.tag) .. ') tree:(' .. helpers.as_string(ast) .. ')')
    end
end

function generate_statement(state, ast)
    local is_statement = true
    if ast.tag == 'assign' then
        generate_assignment(state, ast)
    elseif ast.tag == 'local' then

    elseif ast.tag == 'return' then
        generate_expression(state, ast.expression)
        pushCode(state, 'ret')
    elseif ast.tag == 'prt' then
        generate_expression(state, ast.expression)
        pushCode(state, 'prt')
    elseif ast.tag == 'function_call' then
        generate_function_call(state, ast)
        pushCode(state, 'pop')
        pushCode(state, 1)
    elseif ast.tag == 'empty' then
    elseif ast.tag == 'block' then
        --print('compile block -> '.. helpers.as_string(ast))
        current_block = current_block + 1
        pushCode(state, 'open_block')
        generate_statement(state, ast.block)
        pushCode(state, 'close_block')
    elseif ast.tag == 'while' then
        pushCode(state, 'open_block')
        while_label = get_exec_plan_position(state)
        generate_expression(state, ast.condition)
        local jump_position = generate_conditional_jump_false(state)
        generate_statement(state, ast.while_block.block)
        generate_jump_label(state, while_label)
        fix_jump_current_position(state, jump_position)
        pushCode(state, 'close_block')
    elseif ast.tag == 'seq' then
        if ast.statement_1.is_statement then
            generate_statement(state, ast.statement_1)
        elseif ast.statement_1.is_error then
            generate_error(state, ast)
        else
            generate_expression(state, ast.statement_1)
        end
        if ast.statement_2.is_statement then
            generate_statement(state, ast.statement_2)
        elseif ast.statement_2.is_error then
            generate_error(state, ast)
        else
            generate_expression(state, ast.statement_2)
        end
    elseif ast.tag == 'if' then
        generate_expression(state, ast.condition)
        local jump_position = generate_conditional_jump_false(state)
        generate_statement(state, ast.if_block)
        if not ast.else_block then
            fix_jump_current_position(state, jump_position)
        else
            else_jump = generate_unconditional_jump(state)
            fix_jump_current_position(state, jump_position)
            generate_statement(state, ast.else_block)
            fix_jump_current_position(state, else_jump)
        end
    elseif ast.tag == 'unless' then
        generate_expression(state, ast.condition)
        local jump_position = generate_conditional_jump_true(state)
        generate_statement(state, ast.unless_block)

        if not ast.else_block then
            fix_jump_current_position(state, jump_position)
        else
            else_jump = generate_unconditional_jump(state)
            fix_jump_current_position(state, jump_position)

            generate_statement(state, ast.else_block)

            fix_jump_current_position(state, else_jump)
        end
    else
        error('Compilation Error: invalid statement. tag:(' .. ast.tag .. ') tree:(' .. helpers.as_string(ast) .. ')')
    end
end

function compile(ast)
    local state = { functions = {}, exec_plan = {}, vars = {}, num_of_vars = 0 }
    for i = 1, #ast do
        local current_ast = ast[i]
        if current_ast.tag == 'function_declaration' then
            generate_function_definition(state, current_ast)
        else
            if current_ast.is_statement then
                generate_statement(state, current_ast)
            elseif current_ast.is_error then
                generate_error(state, current_ast)
            else
                generate_expression(state, current_ast)
            end
            pushCode(state, 'push')
            pushCode(state, 0)
            pushCode(state, 'ret')
            return state.exec_plan

        end
    end
    local main = state.functions['main']
    if not main then
        error('Compilation Error: main function not found.')
    end
    return main.exec_plan
end

compiler.compile = compile

return compiler