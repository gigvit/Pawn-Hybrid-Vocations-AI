local common = {}

function common.bool_text(value)
    return value and "yes" or "no"
end

function common.draw_field(label, value)
    imgui.text(label .. ": " .. tostring(value == nil and "<nil>" or value))
end

return common
