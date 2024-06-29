--[[
Govee QuickApp
@author ikubicki
@version 1.0.0
]]

function QuickApp:turnOn()
    self:setValue(99)
    self.sdk:powerSwitch(1)
end

function QuickApp:turnOff()
    self:setValue(0)
    self.sdk:powerSwitch(0)
end

function QuickApp:setValue(value)
    self:updateProperty("value", value)
    self:changeBrightness(value)
end

function QuickApp:setColor(r, g, b, w, dontPopulate)
    local color = string.format("%d,%d,%d,%d", r or 0, g or 0, b or 0, w or 0) 
    self:updateProperty("color", color)
    self:setColorComponents({red = r, green = g, blue = b, warmWhite = w}, dontPopulate)
end

function QuickApp:setColorComponents(colorComponents, dontPopulate)
    local cc = self.properties.colorComponents
    if colorComponents["warmWhite"] ~= nil and cc["warmWhite"] ~= colorComponents["warmWhite"] then
        colorComponents = {
            red = 255,
            green = 255,
            blue = 255,
            warmWhite = colorComponents["warmWhite"],
        }
    end
    local isColorChanged = false
    for k,v in pairs(colorComponents) do
        if cc[k] and cc[k] ~= v then
            cc[k] = v
            isColorChanged = true
        end
    end
    if isColorChanged == true then
        self:updateProperty("colorComponents", cc)
        if not dontPopulate then
            self:changeColor(cc)
        end
        self:setColor(cc["red"], cc["green"], cc["blue"], cc["warmWhite"], dontPopulate)
        self:updateView("status", "text", "Color updated")
    end
end

function QuickApp:changeBrightness(value)
    if not self.sdk:canMakeCalls() then return end
    if value > 0 then
        if self.properties.value < 1 then
            self.sdk:powerSwitch(1)
            self:setValue(100)
        end
        self.sdk:setBrightness(value)
    else
        if self.properties.value > 0 then
            self.sdk:powerSwitch(0)
            self:setValue(0)
        end
        self.sdk:setBrightness(0)
    end
end

function QuickApp:changeColor(rgbw)
    if not self.sdk:canMakeCalls() then return end
    if self.properties.value < 1 then
        self.sdk:powerSwitch(1)
        self:setValue(99)
    end
    self.sdk:setColor(rgbw)
end

function QuickApp:onInit()
    self:updateProperty("colorComponents", {red=0, green=0, blue=0, warmWhite=0})
    self.sdk = sdk:new({
        apikey = self:getVariable("ApiKey"),
        deviceID = self:getVariable("DeviceID"),
        debug = self:getVariable("Debug"),
    })
    self.interval = self:getVariable('Interval')
    if not self.interval or self.interval == "" then
        self.interval = 60
    end
    self:updateView("label1", "text", "Govee QuickApp")
    -- self:updateView("listDevices", "visible", true)
    -- self:updateView("updateDevice", "visible", false)

    if not self.sdk:hasApiKey() then
        self:updateView("label1", "text", "API KEY not set. Please update the settings.")
        -- self:updateView("listDevices", "visible", false)
    elseif not self.sdk:hasDeviceID() then
        self:updateView("label1", "text", "Device ID not set. Please click list devices and update the settings.")
    else
        -- self:updateView("listDevices", "visible", false)
        -- self:updateView("updateDevice", "visible", true)
    end
    self:run()
end

function QuickApp:run()
    self:updateDevice()
    if self.sdk:canMakeCalls() then
        local interval = self.interval * 1000
        if self.properties.dead then
            interval = 3600000
        end
        fibaro.setTimeout(interval, function() self:run() end)
    end
end

function QuickApp:updateDevice()
    local resolve = function (device)
        -- QuickApp:debug(json.encode(device))
        -- QuickApp:debug('online', device.online)
        -- QuickApp:debug('brightness', device.brightness)
        -- QuickApp:debug('rgb', json.encode(device.rgb))
        -- QuickApp:debug('powerSwitch', device.powerSwitch)
        -- QuickApp:debug('warmWhite', device.warmWhite)
        if not device.rgb then device.rgb = {red = nil, green = nil, blue = nil} end
        if not device.powerSwitch then device.brightness = 0 end
        self:setColorComponents({
            red = device.rgb.red,
            green = device.rgb.green,
            blue = device.rgb.blue,
            warmWhite = device.warmWhite
        }, true)
        self:updateProperty("value", device.brightness)
        if device.online then
            self:updateProperty("dead", false)
            self:updateProperty("deadReason", nil)
        else 
            self:updateProperty("dead", true)
            self:updateProperty("deadReason", "Device offline")
        end
        self:updateView("label1", "text", "Device information updated at " .. os.date('%Y-%m-%d %H:%M:%S'))
    end
    local reject = function (response)
        QuickApp:debug(json.encode(response))
    end
    if self.sdk:canMakeCalls() then
        self.sdk:getDeviceStatus(resolve, reject)
    end
end

function QuickApp:listDevices()
    local resolve = function (devices)
        self:updateView("label1", "text", #devices .. " device(s) found.<br />Check the logs of the application to see the list.");
        for _, device in ipairs(devices) do
            -- QuickApp:trace(json.encode(device))
            if device.type == 'devices.types.light' then
                QuickApp:trace('🟢 ' .. device.deviceName)
                QuickApp:trace(' .. ID: ' .. device.sku .. '.' .. device.device)
                QuickApp:trace(' .. Type: ' .. device.type)
                QuickApp:trace(' .. Model: ' .. device.sku)
            else
                QuickApp:trace('🔴 ' .. device.deviceName)
                QuickApp:trace(' .. ID: not supported')
                QuickApp:trace(' .. Type: ' .. device.type)
                QuickApp:trace(' .. Model: ' .. device.sku)
            end
        end
        if #devices == 1 and device.type == 'devices.types.light' then
            self:updateView("label1", "text", #devices .. " device(s) found.<br />Device will be assigned to the application automatically.");
            self:setVariable("DeviceID", devices[1].sku .. '.' .. devices[1].device)
        end
    end
    local reject = function (response)
        self:updateView("label1", "text", "Cannot retrieve the list of devices [" .. response.status .. "]");
    end
    self.sdk:listDevices(resolve, reject)
end
