-- SettingsDialog.lua
-- Plugin settings: API key, model selection, excluded keywords (hierarchical tree).

local LrView            = import 'LrView'
local LrDialogs         = import 'LrDialogs'
local LrPrefs           = import 'LrPrefs'
local LrBinding         = import 'LrBinding'
local LrColor           = import 'LrColor'
local LrFunctionContext = import 'LrFunctionContext'
local LrProgressScope   = import 'LrProgressScope'

local VERSION = require 'Version'

local TagManager = require 'TagManager'

local SettingsDialog = {}

local MODELS = {
    { label = 'Sonnet 4.6 (recommandé — meilleur rapport qualité/prix)', value = 'claude-sonnet-4-6' },
    { label = 'Haiku 4.5 (rapide, moins cher, moins précis)',            value = 'claude-haiku-4-5-20251001' },
    { label = 'Opus 4.6 (le plus précis, plus cher)',                    value = 'claude-opus-4-6' },
}

function SettingsDialog.show()
    LrFunctionContext.callWithContext('SettingsDialog', function(context)
    local prefs = LrPrefs.prefsForPlugin()
    local f     = LrView.osFactory()
    local props = LrBinding.makePropertyTable(context)

    -- Load current prefs
    props.apiKey        = prefs.apiKey or ''
    props.model         = prefs.model  or 'claude-sonnet-4-6'
    props.jpegMaxSize   = tostring(prefs.jpegMaxSize or 1500)
    props.jpegQuality   = tostring(prefs.jpegQuality or 80)

    -- Load keyword tree with progress indicator (can be slow on large catalogs)
    local tree
    do
        local progress = LrProgressScope({ title = 'Chargement des mots-clés…' })
        tree = TagManager.getKeywordTree()
        progress:done()
    end
    local excludedSet = {}
    for _, path in ipairs(prefs.excludedKeywords or {}) do
        excludedSet[path] = true
    end

    -- Sanitize fullPath into a valid LrBinding property key (alphanumeric + underscore only)
    local function makeKey(fullPath)
        return 'kw_' .. fullPath:gsub('[^%w]', '_')
    end

    -- Register each keyword as a checkbox property
    local function registerTree(nodes)
        for _, node in ipairs(nodes) do
            local key = makeKey(node.fullPath)
            props[key] = excludedSet[node.fullPath] or false
            if node.children and #node.children > 0 then
                registerTree(node.children)
            end
        end
    end
    registerTree(tree)

    -- Sort nodes alphabetically (case-insensitive), recursively
    local function sortTree(nodes)
        table.sort(nodes, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        for _, node in ipairs(nodes) do
            if node.children and #node.children > 0 then
                sortTree(node.children)
            end
        end
    end
    sortTree(tree)

    -- Categories whose children should appear in red
    local RED_PARENTS = { famille = true, ['not'] = true, not1 = true }

    -- Known first names (leaf nodes with these exact names are coloured blue).
    -- Includes common French and international names in their typical capitalised form.
    local FIRST_NAMES_SET = {}
    for _, n in ipairs({
        -- French masculine
        'Adam','Adrien','Alexis','Antoine','Arthur','Baptiste','Benjamin',
        'Camille','Charles','Christophe','Clement','Clément','Corentin',
        'David','Dylan','Edouard','Édouard','Eric','Éric','Ethan',
        'Felix','Félix','Florent','Florian','François','Francois',
        'Gabriel','Guillaume','Henri','Hugo','Jean','Julien','Justin',
        'Kevin','Laurent','Leo','Léo','Lilian','Louis','Luca','Lucas',
        'Marc','Martin','Mathieu','Mathis','Maxime','Mickael','Michael',
        'Nathan','Nicolas','Noah','Nico','Paul','Philippe','Pierre',
        'Quentin','Raphael','Raphaël','Remi','Rémi','Romain',
        'Sam','Sebastien','Sébastien','Simon','Thomas','Timothee','Timothée',
        'Tom','Tony','Victor','Xavier','Yanis','Yann',
        -- French feminine
        'Adele','Adèle','Agnes','Agnès','Alice','Alicia','Amelie','Amélie',
        'Anais','Anaïs','Andrea','Andréa','Anne','Audrey','Aurelie','Aurélie',
        'Camille','Caroline','Charlotte','Chloe','Chloé','Claire','Clara',
        'Elise','Élise','Ella','Emilie','Émilie','Emma','Eva',
        'Helene','Hélène','Ines','Inès','Iris','Isabelle',
        'Jade','Julie','Justine','Laura','Laure','Lea','Léa',
        'Lena','Léna','Lila','Lily','Lisa','Louise','Lucie','Luna',
        'Manon','Marguerite','Marie','Mathilde','Maya','Melanie','Mélanie',
        'Mia','Nathalie','Nina','Noemie','Noémie','Nora',
        'Oceane','Océane','Olivia','Pauline','Rose',
        'Romane','Sarah','Sophie','Stephanie','Stéphanie','Sylvie',
        'Valentine','Vanessa','Virginie','Viviane','Zoe','Zoé',
        -- International
        'Alex','Ana','Anna','Ben','Carlos','Chris','Dan','Elena',
        'Eli','Felix','James','John','Julia','Maria','Marco','Max',
        'Miguel','Pablo','Peter','Sara','Sofia',
        -- Hyphenated common forms
        'Jean-Pierre','Jean-Paul','Jean-Marie','Jean-Luc','Jean-Claude',
        'Marie-Claire','Marie-Laure','Anne-Sophie','Anne-Laure',
    }) do
        FIRST_NAMES_SET[n] = true
    end

    -- Returns true only for leaf nodes whose name exactly matches a known first name.
    local function looksLikeFirstName(node)
        if node.children and #node.children > 0 then return false end
        return FIRST_NAMES_SET[node.name] == true
    end

    -- Build keyword tree UI recursively
    -- inRedZone = true when an ancestor is famille/not/not1
    local function buildTreeUI(nodes, indent, inRedZone)
        indent    = indent    or 0
        inRedZone = inRedZone or false
        local rows = {}

        for _, node in ipairs(nodes) do
            local key      = makeKey(node.fullPath)
            local hasKids  = node.children and #node.children > 0
            local nodeName = node.name:lower()
            local margin   = indent * 16
            local font     = hasKids and '<system/bold>' or '<system>'

            -- Determine text color
            -- text_color on f:checkbox doesn't work on Windows — we use a separate f:static_text
            local textColor
            if inRedZone then
                textColor = LrColor(0.85, 0.15, 0.15)
            elseif looksLikeFirstName(node) then
                textColor = LrColor(0.15, 0.35, 0.85)
            end

            -- Uniform structure for all items: fixed checkbox (20px) + static_text
            -- This ensures all checkboxes at the same indent level are perfectly aligned
            local labelView
            if textColor then
                labelView = f:static_text {
                    title      = node.name,
                    font       = font,
                    text_color = textColor,
                }
            else
                labelView = f:static_text {
                    title = node.name,
                    font  = font,
                }
            end

            local cbRow = f:row {
                spacing = 0,
                f:spacer { width = margin },
                f:checkbox {
                    title   = '',
                    value   = LrView.bind(key),
                    tooltip = 'Exclure "' .. node.fullPath .. '"',
                    width   = 22,
                },
                labelView,
            }

            rows[#rows + 1] = cbRow

            if hasKids then
                local childRed = inRedZone or RED_PARENTS[nodeName]
                local childRows = buildTreeUI(node.children, indent + 1, childRed)
                for _, cr in ipairs(childRows) do
                    rows[#rows + 1] = cr
                end
            end
        end
        return rows
    end

    local treeRows = buildTreeUI(tree, 0)

    -- Pré-calcul des colonnes (~30 tags/colonne, max 4)
    local rowsPerCol  = 30
    local numCols     = math.min(4, math.max(1, math.ceil(#treeRows / rowsPerCol)))
    local colSize     = math.ceil(#treeRows / numCols)
    local columnViews = {}
    for c = 1, numCols do
        local group    = {}
        local startIdx = (c - 1) * colSize + 1
        local endIdx   = math.min(c * colSize, #treeRows)
        for i = startIdx, endIdx do
            group[#group + 1] = treeRows[i]
        end
        columnViews[#columnViews + 1] = f:column {
            spacing = 2,
            unpack(group),
        }
    end

    -- Model dropdown items
    local modelItems = {}
    for _, m in ipairs(MODELS) do
        modelItems[#modelItems + 1] = { title = m.label, value = m.value }
    end

    local contents = f:column {
        spacing = f:label_spacing(),
        bind_to_object = props,

        -- API Key
        f:group_box {
            title = 'Clé API Anthropic',
            fill_horizontal = 1,
            f:row {
                f:static_text { title = 'Clé API :', width = 80 },
                f:edit_field {
                    value           = LrView.bind('apiKey'),
                    fill_horizontal = 1,
                    immediate       = true,
                },
            },
            f:static_text {
                title      = 'Obtenir une clé sur console.anthropic.com',
                text_color = LrColor(0.5, 0.5, 0.5),
                font       = '<system/small>',
            },
        },

        -- Model
        f:group_box {
            title = 'Modèle Claude',
            fill_horizontal = 1,
            f:popup_menu {
                value = LrView.bind('model'),
                items = modelItems,
                fill_horizontal = 1,
            },
        },

        -- Export settings
        f:group_box {
            title = 'Paramètres d\'export JPEG',
            fill_horizontal = 1,
            f:row {
                f:static_text { title = 'Taille max (px) :', width = 120 },
                f:edit_field {
                    value = LrView.bind('jpegMaxSize'),
                    width_in_chars = 6,
                    validate = function(_, v)
                        local n = tonumber(v)
                        if n and n >= 400 and n <= 4000 then
                            return true, tostring(math.floor(n))
                        end
                        return false, v, 'Entrez un nombre entre 400 et 4000'
                    end,
                },
                f:static_text { title = '(recommandé : 1500)' },
            },
            f:row {
                f:static_text { title = 'Qualité JPEG (%) :', width = 120 },
                f:edit_field {
                    value = LrView.bind('jpegQuality'),
                    width_in_chars = 4,
                    validate = function(_, v)
                        local n = tonumber(v)
                        if n and n >= 40 and n <= 100 then
                            return true, tostring(math.floor(n))
                        end
                        return false, v, 'Entrez un nombre entre 40 et 100'
                    end,
                },
                f:static_text { title = '(recommandé : 80)' },
            },
        },

        -- Tagging rules info
        f:group_box {
            title           = 'Règles d\'analyse Claude',
            fill_horizontal = 1,
            f:static_text {
                title           = 'Si un tag de sous-catégorie est sélectionné, le tag parent générique est automatiquement retiré.\nExemple : "église" sélectionné → "bâtiment" supprimé.',
                fill_horizontal = 1,
                height_in_lines = 2,
                font            = '<system/small>',
            },
        },

        -- Keywords exclusion — colonnes dynamiques
        f:group_box {
            title           = 'Tags exclus (cochés = exclus de l\'analyse Claude)',
            fill_horizontal = 1,

            -- Légende des couleurs
            f:row {
                spacing = 16,
                f:row {
                    spacing = 4,
                    f:static_text { title = '■', text_color = LrColor(0.15, 0.35, 0.85), width = 14 },
                    f:static_text { title = 'Prénom' },
                },
                f:row {
                    spacing = 4,
                    f:static_text { title = '■', text_color = LrColor(0.85, 0.15, 0.15), width = 14 },
                    f:static_text { title = 'famille' },
                },
                f:row {
                    spacing = 4,
                    f:static_text { title = '■', font = '<system/bold>', width = 14 },
                    f:static_text { title = 'Gras = catégorie avec sous-tags' },
                },
            },

            f:spacer { height = 6 },

            f:row {
                spacing = 10,
                unpack(columnViews),
            },
        },
    }

    local result = LrDialogs.presentModalDialog({
        title    = 'LrAutoKeyword ' .. VERSION .. ' — Paramètres',
        contents = contents,
        actionVerb = 'Enregistrer',
        cancelVerb = 'Annuler',
    })

    if result == 'ok' then
        -- Save prefs
        prefs.apiKey      = props.apiKey
        prefs.model       = props.model
        prefs.jpegMaxSize = tonumber(props.jpegMaxSize) or 1500
        prefs.jpegQuality = tonumber(props.jpegQuality) or 80

        -- Collect excluded keyword full paths
        local excluded = {}
        local function collectExcluded(nodes)
            for _, node in ipairs(nodes) do
                local key = makeKey(node.fullPath)
                if props[key] then
                    excluded[#excluded + 1] = node.fullPath
                end
                if node.children and #node.children > 0 then
                    collectExcluded(node.children)
                end
            end
        end
        collectExcluded(tree)
        prefs.excludedKeywords = excluded
        TagManager.invalidateCache()

        LrDialogs.message('Paramètres enregistrés.', '', 'info')
    end
    end) -- end callWithContext
end

return SettingsDialog
