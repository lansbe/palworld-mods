package.path='src/runtime/?.lua;'..package.path
package.loaded['i18n.catalog']={languages={{id='en',name='English'},{id='fr',name='Français'},
    {id='es',name='Español'},{id='es-419',name='Español (Latinoamérica)'},{id='pt-BR',name='Português'},
    {id='zh-Hans',name='简体中文'},{id='zh-Hant',name='繁體中文'},{id='ja',name='日本語'}},
    messages={en={hello='Hello {name}',fallback='English fallback',['language.auto']='Automatic'},fr={hello='Bonjour {name}'}}}
local now,gameLanguage=0,'fr-CA'
Engine={clock=function()return now end,valid=function(value)return value~=nil end,
    find=function()return {GetCurrentLanguage=function()return gameLanguage end}end,json_encode=function()return '{}'end}
local I18n=require('i18n.service')
I18n.tick();assert(I18n.language=='fr' and I18n.mode=='auto')
assert(I18n.core('hello',{name='50% {example}'})=='Bonjour 50% {example}','Interpolation must not interpret replacement text')
assert(I18n.core('fallback')=='English fallback','Missing entries need an English fallback')
assert(I18n.normalize('zh_TW')=='zh-Hant' and I18n.normalize('zh-Hans-CN')=='zh-Hans')
assert(I18n.normalize('es-MX')=='es-419' and I18n.normalize('es-ES')=='es')
assert(I18n.normalize('pt_PT')=='pt-BR' and I18n.normalize('unknown')=='en')
I18n.configure('ja');gameLanguage='es-MX';now=2;I18n.tick()
assert(I18n.language=='ja' and I18n.gameLanguage=='es-419','Manual preference must override game language')
I18n.configure('auto');assert(I18n.language=='es-419','Automatic mode must use the current game language')
assert(not pcall(I18n.configure,'unsupported') and I18n.mode=='auto','Invalid preferences must not replace the current mode')
I18n.register('fixture',{en={name='Example',['choice.a']='A'},fr={name='Exemple',['choice.a']='Un'}})
I18n.configure('fr')
local field={label='name',options={'stable-id'},optionKeys={'choice.a'}}
local translated=I18n.field('fixture',field)
assert(translated.label=='Exemple' and translated.optionLabels[1]=='Un' and translated.options[1]=='stable-id')
assert(field.label=='name' and field.optionLabels==nil,'Translation must not mutate a mod schema')
print('PASS: game detection, overrides, regional aliases, fallback, interpolation and stable option IDs')
