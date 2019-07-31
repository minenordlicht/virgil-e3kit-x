//
// Copyright (C) 2015-2019 Virgil Security Inc.
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     (1) Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//
//     (2) Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in
//     the documentation and/or other materials provided with the
//     distribution.
//
//     (3) Neither the name of the copyright holder nor the names of its
//     contributors may be used to endorse or promote products derived from
//     this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
// IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>
//

import VirgilCrypto
import VirgilCryptoFoundation
import VirgilSDK

extension EThree {    
    public func createGroup(id identifier: Data, with lookup: LookupResult) -> GenericOperation<Group> {
        return CallbackOperation { _, completion in
            do {
                let sessionId = self.computeSessionId(from: identifier)

                let groupManager = try self.getGroupManager()
                let lookupManager = try self.getLookupManager()

                var lookup = lookup
                let selfCard = try lookupManager.lookupCard(of: self.identity)
                lookup[self.identity] = selfCard

                let ticket = try Ticket(crypto: self.crypto,
                                        sessionId: sessionId,
                                        participants: Set(lookup.keys))

                try groupManager.store(ticket, sharedWith: Array(lookup.values))

                let group = try Group(initiator: self.identity,
                                      tickets: [ticket],
                                      crypto: self.crypto,
                                      localKeyStorage: self.localKeyStorage,
                                      groupManager: groupManager,
                                      lookupManager: self.getLookupManager())

                completion(group, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func getGroup(id identifier: Data) throws -> Group? {
        let sessionId = self.computeSessionId(from: identifier)

        let groupManager = try self.getGroupManager()

        guard let group = groupManager.retrieve(sessionId: sessionId) else {
            throw EThreeError.missingCachedGroup
        }

        guard !group.tickets.isEmpty else {
            return nil
        }

        return try Group(initiator: group.info.initiator,
                         tickets: group.tickets,
                         crypto: self.crypto,
                         localKeyStorage: self.localKeyStorage,
                         groupManager: groupManager,
                         lookupManager: self.getLookupManager())
    }

    public func loadGroup(id identifier: Data, initiator card: Card) -> GenericOperation<Group> {
        return CallbackOperation { _, completion in
            do {
                let sessionId = self.computeSessionId(from: identifier)

                let groupManager = try self.getGroupManager()

                try groupManager.pull(sessionId: sessionId, from: card)

                guard let rawGroup = groupManager.retrieve(sessionId: sessionId) else {
                    throw EThreeError.groupWasNotFound
                }

                let group = try Group(initiator: rawGroup.info.initiator,
                                      tickets: rawGroup.tickets,
                                      crypto: self.crypto,
                                      localKeyStorage: self.localKeyStorage,
                                      groupManager: groupManager,
                                      lookupManager: try self.getLookupManager())

                completion(group, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func deleteGroup(id identifier: Data) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let sessionId = self.computeSessionId(from: identifier)

                guard let rawGroup = try self.getGroupManager().retrieve(sessionId: sessionId) else {
                    throw EThreeError.groupWasNotFound
                }

                guard self.identity == rawGroup.info.initiator else {
                    throw EThreeError.groupPermissionDenied
                }

                try self.getGroupManager().delete(sessionId: sessionId)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
