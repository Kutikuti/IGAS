-- Author      : Kurapica
-- Create Date : 2010/12/27
-- Change Log  :
--				2011/03/13	Recode as class
--              2012/07/04  Extend from IFSecureHandler

-- Check Version
local version = 3
if not IGAS:NewAddon("IGAS.Widget.SecureButton", version) then
	return
end

class "SecureButton"
	inherit "Button"
	extend "IFSecureHandler"

	doc [======[
		@name SecureButton
		@type class
		@desc SecureButton is used as the root widget class for secure buttons
	]======]

	------------------------------------------------------
	-- Event
	------------------------------------------------------

	------------------------------------------------------
	-- Method
	------------------------------------------------------

	------------------------------------------------------
	-- Property
	------------------------------------------------------

	------------------------------------------------------
	-- Constructor
	------------------------------------------------------
	function Constructor(self, name, parent, ...)
		if select('#', ...) > 0 then
			return CreateFrame("Button", name, parent, ...)
		else
			return CreateFrame("Button", name, parent, "SecureFrameTemplate")
		end
	end
endclass "SecureButton"
