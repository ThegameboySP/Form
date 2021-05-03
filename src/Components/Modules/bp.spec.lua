local bp = require(script.Parent.bp)

local function makeSchema(func)
	return {
		[bp.childNamed("test")] = {
			[bp.children] = {
				[bp.attribute("Test", true)] = func or function(context)
					return context.instance
				end
			}
		}
	}
end

return function()
	local new = Instance.new

	describe("Schema", function()
		local temp = makeSchema()

		local i do
			i = new("Folder")

			local one = new("Folder")
			one.Name = "test"
			one.Parent = i

			local two = new("Folder")
			two.Name = "test2"
			two.Parent = one
			two:SetAttribute("Test", true)
		end

		it("should cache when initial match", function()
			local clone = i:Clone()
			local schema = bp.new(clone, temp)

			expect(schema:GetMatched()[1]).to.equal(clone.test.test2)
		end)

		it("should cache when later match", function()
			local folder = new("Folder")
			local schema = bp.new(folder, temp)

			expect(schema:GetMatched()[1]).to.equal(nil)
			i.test:Clone().Parent = folder
			expect(schema:GetMatched()[1]).to.equal(folder.test.test2)
		end)
		
		it("should fire event when match", function()
			local folder = new("Folder")
			local schema = bp.new(folder, temp)

			local values = {}
			schema.Matched:Connect(function(found)
				table.insert(values, found)
			end)

			expect(values[1]).to.equal(nil)

			i.test:Clone().Parent = folder
			expect(#values).to.equal(1)
			expect(values[1]).to.equal(folder.test.test2)
		end)

		it("should remove a tree that is no longer a match", function()
			local clone = i:Clone()
			local schema = bp.new(clone, temp)

			expect(schema:GetMatched()[1]).to.equal(clone.test.test2)

			clone.test:Destroy()

			expect(schema:GetMatched()[1]).to.equal(nil)
		end)

		it("should continue when function meets criteria", function()
			local clone = i:Clone()
			local schema = bp.new(clone, makeSchema(function()
				return false, {
					[bp.childNamed("test3")] = function(context)
						return context.instance
					end
				}
			end))

			expect(schema:GetMatched()[1]).to.equal(nil)

			local test3 = new("Folder")
			test3.Name = "test3"
			test3.Parent = clone.test.test2

			expect(schema:GetMatched()[1]).to.equal(test3)
		end)
	end)
end