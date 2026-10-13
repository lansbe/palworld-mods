local data=require('i18n.catalog')
local I18n={mode='auto',language='en',gameLanguage='en',revision=0,catalogs={core=data.messages}}
local supported={}
for _,entry in ipairs(data.languages) do supported[entry.id:lower()]=entry.id end
function I18n.normalize(value)
    local tag=tostring(value or ''):gsub('_','-'):lower()
    if supported[tag] then return supported[tag] end
    if tag:match('^zh') then
        return (tag:find('hant',1,true) or tag:match('^zh%-tw') or tag:match('^zh%-hk') or tag:match('^zh%-mo')) and 'zh-Hant' or 'zh-Hans'
    end
    if tag:match('^es%-') and not tag:match('^es%-es') then return 'es-419' end
    if tag:match('^pt') then return 'pt-BR' end
    return supported[tag:match('^[a-z]+') or ''] or 'en'
end
function I18n.register(domain,catalogs)
    assert(type(domain)=='string' and type(catalogs)=='table' and type(catalogs.en)=='table','Invalid localization catalogue')
    I18n.catalogs[domain]=catalogs
end
function I18n.t(domain,key,arguments)
    local catalogs=I18n.catalogs[domain] or {}
    local translated=catalogs[I18n.language] or {}
    local template=translated[key] or (catalogs.en or {})[key] or key
    return (template:gsub('{([%w_]+)}',function(name)
        local value=(arguments or {})[name]
        return value~=nil and tostring(value) or '{'..name..'}'
    end))
end
function I18n.core(key,arguments) return I18n.t('core',key,arguments) end
function I18n.state() return {mode=I18n.mode,language=I18n.language,game_language=I18n.gameLanguage} end
local function resolve()
    local language=I18n.mode=='auto' and I18n.gameLanguage or I18n.mode
    if language~=I18n.language then I18n.language=language;I18n.revision=I18n.revision+1 end
end
function I18n.configure(mode)
    assert(mode=='auto' or supported[tostring(mode):lower()]==mode,'Unsupported language preference')
    I18n.mode=mode;resolve();return I18n.state()
end
function I18n.tick()
    local now=Engine.clock()
    if now<(I18n.nextCheck or 0) then return end
    I18n.nextCheck=now+1
    local library=Engine.find('/Script/Engine.Default__KismetInternationalizationLibrary')
    if not Engine.valid(library) then return end
    local language=I18n.normalize(library:GetCurrentLanguage())
    if not I18n.detected or language~=I18n.gameLanguage then
        I18n.detected=true;I18n.gameLanguage=language;resolve()
        print('[PalModsIPC]'..Engine.json_encode({event='language_detected',language=language}))
    end
end
function I18n.choices()
    local ids,labels={'auto'},{I18n.core('language.auto')}
    for _,entry in ipairs(data.languages) do ids[#ids+1]=entry.id;labels[#labels+1]=entry.name end
    return ids,labels
end
function I18n.field(domain,field)
    local result={};for key,value in pairs(field) do result[key]=value end
    result.label=I18n.t(domain,field.label)
    if field.hint then result.hint=I18n.t(domain,field.hint) end
    if field.optionKeys then
        result.optionLabels={}
        for i,key in ipairs(field.optionKeys) do result.optionLabels[i]=I18n.t(domain,key) end
    end
    return result
end
return I18n
