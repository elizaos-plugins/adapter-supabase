import { supabaseAdapter } from "./client";

const supabasePlugin = {
    name: "supabase",
    description: "Supabase database adapter plugin",
    adapters: [supabaseAdapter],
};
export default supabasePlugin;
