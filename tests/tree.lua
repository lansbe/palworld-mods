package.path='src/runtime/?.lua;'..package.path
Engine={valid=function(widget) return type(widget)=='table' end}
local Tree=require('ui.tree')
Tree.visible=function(widget) return widget.visible~=false end
local function node(key,children,visible)
    return {key=key,visible=visible,GetChildrenCount=function() return #(children or {}) end,
        GetChildAt=function(_,index) return children[index+1] end}
end
local hiddenChildren={}
for i=1,100 do hiddenChildren[i]=node('hidden-'..i) end
local root=node('root',{node('hidden',hiddenChildren,false),node('panel',{node('language-arrow')})})
local function find(widget) if widget.key=='language-arrow' then return widget end end
assert(Tree.walk(root,find,8,true).key=='language-arrow','Hidden branches must not exhaust the visible traversal budget')
assert(Tree.walk(root,find,8)==nil,'Full traversal must retain its existing budget')
assert(Tree.walk(root,find,120).key=='language-arrow','Full traversal must retain hidden descendants')
print('PASS: visible traversal prunes hidden branches without changing full traversal')
