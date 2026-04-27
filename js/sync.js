var SUPABASE_URL = 'https://gojrxctlwxvdvmzftlov.supabase.co';
var SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdvanJ4Y3Rsd3h2ZHZtemZ0bG92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMTE5ODAsImV4cCI6MjA5Mjg4Nzk4MH0.mpHWNiVlUl3UgObOqeIwtxl0rEgKLWL7kt58JDScJp8';

var supabase = null;
var channel = null;
var currentRoomCode = null;

async function getClient() {
    if (supabase) return supabase;
    var mod = await import('https://esm.sh/@supabase/supabase-js@2');
    supabase = mod.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    return supabase;
}

function generateRoomCode() {
    var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var code = '';
    for (var i = 0; i < 6; i++) {
        code += chars[Math.floor(Math.random() * chars.length)];
    }
    return code;
}

export async function createRoom() {
    var client = await getClient();
    currentRoomCode = generateRoomCode();

    channel = client.channel('room:' + currentRoomCode, {
        config: { broadcast: { self: false } }
    });

    await channel.subscribe();
    return currentRoomCode;
}

export async function joinRoom(code, callbacks) {
    var client = await getClient();
    currentRoomCode = code.toUpperCase();

    channel = client.channel('room:' + currentRoomCode, {
        config: { broadcast: { self: false } }
    });

    channel.on('broadcast', { event: 'state' }, function(payload) {
        if (callbacks.onState) callbacks.onState(payload.payload);
    });

    var status = await channel.subscribe();
    if (status === 'CHANNEL_ERROR' && callbacks.onDisconnect) {
        callbacks.onDisconnect();
    }

    return channel;
}

export function broadcastState(state) {
    if (!channel) return;
    channel.send({
        type: 'broadcast',
        event: 'state',
        payload: state
    });
}

export function sendCommand(cmd) {
    if (!channel) return;
    channel.send({
        type: 'broadcast',
        event: 'command',
        payload: cmd
    });
}

export function onCommand(callback) {
    if (!channel) return;
    channel.on('broadcast', { event: 'command' }, function(payload) {
        callback(payload.payload);
    });
}

export function getRoomCode() {
    return currentRoomCode;
}

export function disconnect() {
    if (channel) {
        channel.unsubscribe();
        channel = null;
    }
    currentRoomCode = null;
}
