--!strict
-- Profile-Migrationen. Bei jedem Schema-Bump neue Funktion hinzufügen.
-- Migrationen werden idempotent in Reihenfolge ausgeführt, bis profile.version == CURRENT.

local DefaultProfile = require(script.Parent.DefaultProfile)

export type Profile = DefaultProfile.Profile

local Migrations = {}

-- CURRENT muss mit DefaultProfile.default().version übereinstimmen.
Migrations.CURRENT = 1

-- Lückenfüller: kopiert fehlende Felder aus dem Default-Schema in das Profile.
-- Wird nach jeder Migration aufgerufen, um neue Felder zuverlässig zu setzen.
local function ensureFields(target: any, source: any)
	if type(target) ~= "table" or type(source) ~= "table" then return end
	for key, value in pairs(source) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = {}
				ensureFields(target[key], value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			ensureFields(target[key], value)
		end
	end
end

-- Beispielmigration für späteren Bump v1 → v2:
-- Migrations[2] = function(profile)
--     profile.newField = "default"
-- end

function Migrations.apply(profile: Profile): Profile
	if not profile.version then profile.version = 1 end
	while profile.version < Migrations.CURRENT do
		local step = profile.version + 1
		local migrate = Migrations[step]
		if migrate then
			migrate(profile)
		end
		profile.version = step
	end
	-- Fülle fehlende Felder, falls Schema im Default um neue Subkeys ergänzt wurde.
	ensureFields(profile, DefaultProfile.default())
	return profile
end

return Migrations
