---
--- Generated by Luanalysis
--- Created by rodelbianco.
--- DateTime: 4/1/23 12:20 PM
---

local helpers = require('./utils/helpers')

function math_fold(list)
    local acc = list[1]
    for i = 2, #list, 2 do
        if list[i] == '+' then
            acc = acc + list[i + 1]
        elseif list[i] == '-' then
            acc = acc - list[i + 1]
        elseif list[i] == '*' then
            acc = acc * list[i + 1]
        elseif list[i] == '/' then
            acc = acc / list[i + 1]
        elseif list[i] == '^' then
            acc = acc ^ list[i + 1]
        elseif list[i] == '%' then
            acc = acc % list[i + 1]
        else
            error('unknown operation -> [' .. helpers.as_string(list[i]) .. ']')
        end
    end
    return acc
end