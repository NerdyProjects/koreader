local DocumentRegistry = require("document/documentregistry")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local DocSettings = require("docsettings")
local DEBUG = require("dbg")
local _ = require("gettext")

local Screensaver = {
}

local function createWidgetFromImage(imageWidget)
    if imageWidget then
        local AlphaContainer = require("ui/widget/container/alphacontainer")
        local CenterContainer = require("ui/widget/container/centercontainer")
        return AlphaContainer:new{
            alpha = 1,
            height = Screen:getHeight(),
            width = Screen:getWidth(),
            CenterContainer:new{
                dimen = Screen:getSize(),
                imageWidget,
            }
        }
    end
end

local function createWidgetFromFile(file)
    if lfs.attributes(file, "mode") == "file" then
        local ImageWidget = require("ui/widget/imagewidget")
        return createWidgetFromImage(
                   ImageWidget:new{
                       file = file,
                       height = Screen:getHeight(),
                       width = Screen:getWidth(),
                       autostretch = true,
                   })
    end
end

local function getRandomImage(dir)
    if string.sub(dir, string.len(dir)) ~= "/" then
       dir = dir .. "/"
    end
    local pics = {}
    local i = 0
    math.randomseed(os.time())
    for entry in lfs.dir(dir) do
        if lfs.attributes(dir .. entry, "mode") == "file" then
            local extension =
                string.lower(string.match(entry, ".+%.([^.]+)") or "")
            if extension == "jpg"
            or extension == "jpeg"
            or extension == "png" then
                i = i + 1
                pics[i] = entry
            end
        end
    end
    return createWidgetFromFile(dir .. pics[math.random(i)])
end

function Screensaver:getCoverImage(file)
    local ImageWidget = require("ui/widget/imagewidget")
    local doc = DocumentRegistry:openDocument(file)
    if doc then
        local image = doc:getCoverPageImage()
        doc:close()
        local lastfile = G_reader_settings:readSetting("lastfile")
        local data = DocSettings:open(lastfile)
        local proportional_cover = data:readSetting("proportional_screensaver")
        if image then
            return createWidgetFromImage(
                       ImageWidget:new{
                           image = image,
                           height = Screen:getHeight(),
                           width = Screen:getWidth(),
                           autostretch = proportional_cover,
                       })
        end
    end
end

function Screensaver:show()
    DEBUG("show screensaver")
    local InfoMessage = require("ui/widget/infomessage")
    -- first check book cover image
    if KOBO_SCREEN_SAVER_LAST_BOOK then
        local lastfile = G_reader_settings:readSetting("lastfile")
        if lastfile then
            local data = DocSettings:open(lastfile)
            local exclude = data:readSetting("exclude_screensaver")
            if not exclude then
                self.suspend_msg = self:getCoverImage(lastfile)
            end
        end
    end
    -- then screensaver directory or file image
    if not self.suspend_msg then
        if type(KOBO_SCREEN_SAVER) == "string" then
            local file = KOBO_SCREEN_SAVER
            if lfs.attributes(file, "mode") == "directory" then
                self.suspend_msg = getRandomImage(file)
            else
                self.suspend_msg = createWidgetFromFile(file)
            end
        end
    end
    -- fallback to suspended message
    if not self.suspend_msg then
        self.suspend_msg = InfoMessage:new{ text = _("Suspended") }
        UIManager:show(self.suspend_msg)
    else
        -- refresh whole screen for other types
        UIManager:show(self.suspend_msg, "full")
    end
end

function Screensaver:close()
    DEBUG("close screensaver")
    if self.suspend_msg then
        UIManager:close(self.suspend_msg)
        self.suspend_msg = nil
    end
end

return Screensaver
