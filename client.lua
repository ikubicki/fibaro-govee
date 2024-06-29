--[[
HTTP client
@author ikubicki
]]

class 'client'

function client:new(options)
    self.options = options or {}
    return self
end

function client:get(path, resolve, reject)
    self:request(self:url(path), self:buildOptions(resolve, reject, 'GET')) 
end

function client:post(path, data, resolve, reject)
    self:request(self:url(path), self:buildOptions(resolve, reject, 'POST', data)) 
end

function client:put(path, data, resolve, reject)
    self:request(self:url(path), self:buildOptions(resolve, reject, 'PUT', data)) 
end

function client:delete(path, resolve, reject)
    self:request(self:url(path), self:buildOptions(resolve, reject, 'DELETE')) 
end

function client:request(url, options)
    if self.options.show_debug then 
        QuickApp:debug("Making a " .. options.options.method .. " to " .. url)
        QuickApp:debug(json.encode(options.options))
    end
    local httpclient = net.HTTPClient({timeout=10000})
    httpclient:request(url, options) 
end

function client:url(path)
    if (string.sub(path, 0, 4) == 'http') then
        return path
    end
    if not self.options.base_url then
        self.options.base_url = 'http://localhost'
    end
    return self.options.base_url .. tostring(path)
end

function client:buildOptions(resolve, reject, method, data)
    
    local success = function (response)
        if response.status < 300 then
            return resolve(response)
        end
        if self.options.show_errors then
            QuickApp:error("Error response [" .. response.status .. "]")
            QuickApp:error(response.data)
        end
        return reject({
            status = response.status
        })
    end
    
    local error = function (error)
        reject(error)
    end

    if (method == nil) then
        method = 'GET'
    end
    local options = {
        checkCertificate = false,
        method = method,
        headers = {
            ["Content-Type"] = 'application/json', 
            ["Govee-API-Key"] = self.options.apikey or '',
        },
    }
    if (data ~= nil) then
        options.data = json.encode(data)
    end
    return {
        options = options,
        success = success,
        error = error
    }
end