namespace WorldScript
{
	[WorldScript color="200 200 100" icon="system/icons.png;416;128;32;32"]
	class PayloadBeginTrigger
	{
		void Initialize()
		{
			g_payloadBeginTriggers.insertLast(this);
		}

		SValue@ ServerExecute()
		{
			return null;
		}
	}
}
