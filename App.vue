<script setup>
import { ref, onMounted, watch } from 'vue';
import { AuthClient } from "@dfinity/auth-client";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { filia_backend } from 'declarations/filia_backend/index';
import { IcrcLedgerCanister } from "@dfinity/ledger-icrc";


const balance = ref(0);
const amount = ref(0);
const principalid = ref('');
const principal = ref('');
const isAuthenticated = ref(false);
const authClient = ref(null);
const adres_internet_identity = ref('');
const transferStatus = ref('');

const ledgerCanisterId = "bkyz2-fmaaa-aaaaa-qaaaq-cai";


const defaultSubaccount = new Uint8Array(32);

const nowInBigIntNanoSeconds = () => BigInt(Date.now()) * BigInt(1000000);



async function sendTokens() {
  try {
    if (!principalid.value || !amount.value) {
      transferStatus.value = "Proszę wypełnić wszystkie pola";
      return;
    }

    if (!isAuthenticated.value) {
      transferStatus.value = "Musisz być zalogowany, aby wykonać transfer";
      return;
    }

    transferStatus.value = "Przetwarzanie transferu...";

    const agent = new HttpAgent();
    if (process.env.DFX_NETWORK !== "ic") {
      await agent.fetchRootKey();
    }
    agent.replaceIdentity(authClient.value.getIdentity());

    const ledgerCanister = IcrcLedgerCanister.create({
      agent,
      canisterId: Principal.fromText(ledgerCanisterId)
    });

 
    const transferParams = {
      to: {
        owner: Principal.fromText(principalid.value),
        subaccount: [] 
      },
      amount: BigInt(amount.value) 
    };

    console.log("Parametry transferu:", transferParams);

 
    const result = await ledgerCanister.transfer(transferParams);
    
    console.log("Pełny wynik transferu:", result);
    
    console.log(result);
    if (typeof result == 'bigint')
    {
      console.log('transfer udany');
      transferStatus.value = 'Transfer Udany ✅';
      await checkBalance();
    }
    else 
    {
      console.log('transfer ! Nieudany ');
      transferStatus.value = 'Problem z Transferem  ❌';
        await checkBalance();
    }
    
  } catch (error) {
    console.error("Pełne szczegóły błędu:", error);
    transferStatus.value = `Błąd transferu: ${error.message || JSON.stringify(error)}`;
  }
}



async function initializeAuthClient() {
    try {
        authClient.value = await AuthClient.create();
        if (await authClient.value.isAuthenticated()) {
            await onIdentityUpdate();
            await handleWhoami();
            await checkBalance();
        }
    } catch (error) {
        console.error("Error initializing AuthClient:", error);
    }
}


async function checkBalance() {
    try {
        if (!isAuthenticated.value) {
            balance.value = 0;
            return;
        }
        const ball = await filia_backend.checkBalance();
        balance.value = ball;
        console.log("Pobrano saldo:", ball);
    } catch (error) {
        console.error("Błąd podczas sprawdzania salda:", error);
        balance.value = -1;
    }
}


async function onIdentityUpdate() {
    try {
        if (authClient.value && authClient.value.getIdentity()) {
            Actor.agentOf(filia_backend).replaceIdentity(authClient.value.getIdentity());
            isAuthenticated.value = await authClient.value.isAuthenticated();
            console.log("Tożsamość zaktualizowana, zalogowano:", isAuthenticated.value);
        } else {
            isAuthenticated.value = false;
        }
    } catch (error) {
        console.error("Błąd podczas aktualizacji tożsamości:", error);
        isAuthenticated.value = false;
    }
}


async function handleLogin() {
    await handleLogout();
    try {
        const newAuthClient = await AuthClient.create();
        await new Promise((resolve, reject) => {
            newAuthClient.login({
                identityProvider: adres_internet_identity.value,
                onSuccess: resolve,
                onError: (error) => {
                    console.error("Błąd logowania:", error);
                    reject(error);
                }
            });
        });
        authClient.value = newAuthClient;
        await onIdentityUpdate();
        await handleWhoami();
        await checkBalance();
    } catch (error) {
        console.error("Login error:", error);
        transferStatus.value = `Błąd logowania: ${error.message || JSON.stringify(error)}`;
    }
}


async function handleLogout() {
    try {
        await authClient.value.logout();
        isAuthenticated.value = false;
        principal.value = '';
        balance.value = 0;
    } catch (error) {
        console.error("Błąd podczas wylogowywania:", error);
        isAuthenticated.value = false;
    }
}

async function handleWhoami() {
    try {
        if (!isAuthenticated.value) {
            principal.value = '';
            return;
        }
        const result = await filia_backend.whoami();
        principal.value = result.toString();
        console.log("Principal użytkownika:", principal.value);
    } catch (error) {
        console.error("Błąd podczas pobierania principal:", error);
        principal.value = '';
    }
}


function identityProvider() {
 
    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
    
    if (process.env.DFX_NETWORK === "local") {
        adres_internet_identity.value = isSafari 
            ? "http://localhost:4943/?canisterId=b77ix-eeaaa-aaaaa-qaada-cai#authorize" 
            : "http://b77ix-eeaaa-aaaaa-qaada-cai.localhost:4943/#authorize";
    } else {
        adres_internet_identity.value = "https://identity.ic0.app";
    }
    
    console.log("Ustawiono dostawcę tożsamości:", adres_internet_identity.value);
}

onMounted(async () => {
    console.log("Komponent zamontowany, inicjalizacja...");
    identityProvider();
    await initializeAuthClient();
});

watch(isAuthenticated, async (newValue) => {
    console.log("Zmiana stanu uwierzytelnienia:", newValue);
    if (newValue) {
        await handleWhoami();
        await checkBalance();
    } else {
        principal.value = '';
        balance.value = 0;
    }
});
</script>

<template>
  <p>Internet Identity: {{ principal }}</p>
  <p>Zalogowano: {{ isAuthenticated }}</p>
  <button @click="handleLogin" style="width:200px;background-color: aqua;">Login</button>
  <button @click="handleLogout" style="width:200px;background-color:coral">Logout</button>

  <br>
  <p>Środki: {{ balance }} FORSA</p>

  <div class="container">
    <h2>Przelew Tokenów</h2>
    <form @submit.prevent="sendTokens">
        <label>Ilość do wysłania:</label>
        <input type="number" min="1" required v-model="amount">
        
        <label for="principal">Principal odbiorcy:</label>
        <input type="text" id="principal" name="principal" required v-model="principalid">
        
        <button type="submit">Wyślij</button>
    </form>
    <p>{{ transferStatus }}</p>
  </div>

  <button @click="checkBalance">Check Tokens Balance</button>
</template>
