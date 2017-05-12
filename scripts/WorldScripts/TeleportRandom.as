namespace WorldScript
{
	[WorldScript color="63 92 198" icon="system/icons.png;416;64;32;32"]
	class TeleportRandom
	{
		[Editable]
		array<CollisionArea@>@ Areas;

		[Editable type=flags default=2]
		AreaFilter Filter;
		
		[Editable validation=IsValid]
		UnitFeed Destinations;

		bool IsValid(UnitPtr unit)
		{
			return WorldScript::GetWorldScript(unit) !is null;
		}
		
		UnitSource Teleported;

		void Initialize()
		{
			if (Network::IsServer())
			{
				for (uint i = 0; i < Areas.length(); i++)
					Areas[i].AddOnEnter(this, "OnEnter");
			}
		}

		void OnEnter(UnitPtr unit, vec2 pos, vec2 normal)
		{
			if (!Network::IsServer())
				return;
		
			auto ws = WorldScript::GetWorldScript(g_scene, this);
			if (!ws.IsEnabled() || ws.GetTriggerTimes() == 0)
				return;

			if (!ApplyAreaFilter(unit, Filter))
				return;

			TeleportToRandom(unit);
			
			ws.Execute();
		}

		void OnEnabledChanged(bool enabled)
		{
			if (!enabled)
				return;
				
			if (!Network::IsServer())
				return;

			auto script = WorldScript::GetWorldScript(g_scene, this);
			for (uint i = 0; i < Areas.length(); i++)
			{
				auto units = Areas[i].FetchAllInside(g_scene);
				for (uint j = 0; j < units.length; j++)
				{
					UnitPtr unit = units[j];
					
					if (!ApplyAreaFilter(unit, Filter))
						continue;

					TeleportToRandom(unit);

					script.Execute();
				}
			}
		}
		
		void TeleportToRandom(UnitPtr unit)
		{
			array<WorldScript@> destinations;
		
			auto dest = Destinations.FetchAll();
			for (uint i = 0; i < dest.length(); i++)
			{
				WorldScript@ script = WorldScript::GetWorldScript(dest[i]);
				if (script !is null && script.IsExecutable() && script.GetTriggerTimes() != 0 && script.IsEnabled())
					destinations.insertLast(script);
			}
			
			if (destinations.length() == 0)
				return;
			
			int n = randi(destinations.length);
			vec3 randPos = destinations[n].GetUnit().GetPosition();

			Teleported.Replace(unit);
			(Network::Message("UnitTeleported") << unit << xy(randPos)).SendToAll();
			unit.SetPosition(randPos);
			
			destinations[n].Execute();
		}

		SValue@ ServerExecute()
		{
			return null;
		}
	}
}
