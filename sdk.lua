--[[
Govee SDK
@author ikubicki
]]

class 'sdk'

function sdk:new(options)
    self.deviceSKU = ""
    self.deviceID = ""
    if options.deviceID and options.deviceID ~= "" then
        local position = string.find(options.deviceID, "%.")
        self.deviceSKU = string.sub(options.deviceID, 1, position - 1)
        self.deviceID = string.sub(options.deviceID, position + 1)
    end
    self.requestID = 0
    self.apikey = options.apikey
    self.client = client:new({
        base_url = 'https://openapi.api.govee.com',
        apikey = options.apikey,
        show_debug = options.debug and options.debug ~= "",
        show_errors = true,
    })
    return self
end

function sdk:canMakeCalls()
    return self:hasDeviceID() and self:hasApiKey()
end

function sdk:hasDeviceID()
    return string.len(self.deviceID) > 10 and (string.find(self.deviceID, "%.") or self.deviceSKU)
end

function sdk:hasApiKey()
    return string.len(self.apikey) > 3
end

function sdk:listDevices(resolve, reject)
    local _resolve = function(response)
        if resolve then resolve(json.decode(response.data).data) end
    end
    self.client:get('/router/api/v1/user/devices', _resolve, reject)
end

function sdk:buildPayload(capability)
    self.requestID = self.requestID + 1
    return {
        requestId = self.requestID,
        payload = {
            sku = self.deviceSKU,
            device = self.deviceID,
            capability = capability
        }
    }
end

function sdk:getDeviceStatus(resolve, reject)
    local _resolve = function(response)
        local response = json.decode(response.data)
        local status = {}
        for _, capability in ipairs(response.payload.capabilities) do
            if self:shouldSet(capability.state.value) then
                status[capability.instance] = capability.state.value
                if capability.instance == 'colorTemperatureK' then
                    status['warmWhite'] = self:kelvintoint(status['colorTemperatureK'])
                    status['rgb'] = self:inttorgb(16777215) 
                end
                if capability.instance == 'colorRgb' then
                    status['rgb'] = self:inttorgb(status['colorRgb'])
                end
            end
        end
        if resolve then resolve(status) end
    end
    local payload = sdk:buildPayload()
    self.client:post('/router/api/v1/device/state', payload, _resolve, reject)
end

function sdk:shouldSet(value)
    return value ~= "" and value ~= nil and value ~= 0
end

function sdk:powerSwitch(value, resolve, reject)
    self:controlDevice({
        type = "devices.capabilities.on_off",
        instance = "powerSwitch",
        value = value,
    }, resolve, reject)
end

function sdk:setColor(rgbw, resolve, reject)
    if (rgbw.red > 254 and rgbw.green > 254 and rgbw.blue > 254) then
        self:controlDevice({
            type = "devices.capabilities.color_setting",
            instance = "colorTemperatureK",
            value = self:inttokelvin(rgbw.warmWhite),
        }, resolve, reject)
    else
        self:controlDevice({
            type = "devices.capabilities.color_setting",
            instance = "colorRgb",
            value = self:rgbtoint(rgbw),
        }, resolve, reject)
    end
end

function sdk:setBrightness(brightness, resolve, reject)
    self:controlDevice({
        type = "devices.capabilities.range",
        instance = "brightness",
        value = brightness,
    }, resolve, reject)
end

function sdk:controlDevice(capability, resolve, reject)
    local _resolve = function(response)
        if resolve then resolve(json.decode(response.data).payload) end
    end
    local payload = sdk:buildPayload(capability)
    self.client:post('/router/api/v1/device/control', payload, _resolve, reject)
end

function sdk:rgbtoint(rgbw)
    local blue = rgbw.blue
    local green = rgbw.green * 256
    local red = rgbw.red * 65536
    return red + green + blue
end

function sdk:inttorgb(int)
    local blue = int % 256
    local green = (int - blue) % 65536
    local red = int - green - blue
    return {
        red = math.floor(red / 65536),
        green = math.floor(green / 256, 0),
        blue = blue
    }
end

GLITCH_RATIO = 168.647058824
KELVIN_RATIO = 27.4509803922

function sdk:kelvintoint(kelvin)
    if kelvin > 10000 then
        -- when kelvin is expressed between 53255 (warm) and 10250 (cold)
        -- probably an iOS app glitch
        return math.ceil((kelvin - 10250) / GLITCH_RATIO)
    end
    -- when kelvin is expressed between 2k (warm) and 9k (cold)
    return 255 - math.ceil((kelvin - 2000) / KELVIN_RATIO)
end

function sdk:inttokelvin(int)
    return math.floor((255 - int) * KELVIN_RATIO) + 2000
end